Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Fields = @('SchemaVersion','ComputerId','CollectedUtc','Manufacturer','Model','SerialNumber','Processor','RamGiB','FixedVolumeGiB','OsCaption','OsVersion','IPv4')
$script:Utf8 = [Text.UTF8Encoding]::new($true,$true)
$script:Invariant = [Globalization.CultureInfo]::InvariantCulture

function Read-InventoryConfig([string]$Path) {
    $path = [IO.Path]::GetFullPath($Path)
    $cfg = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($key in 'InboxRoot','StageRoot','LogRoot','MasterCsv') {
        if ($cfg.$key -isnot [string] -or [string]::IsNullOrWhiteSpace($cfg.$key)) { throw 'Invalid configuration path.' }
        $value = $cfg.$key
        if ($value -match '^[A-Za-z]:[^\\/]' -or $value -match '^\\[^\\]' -or $value -match '^\\\\[?.]\\') { throw 'Use full drive, UNC, or config-relative paths.' }
        if (![IO.Path]::IsPathRooted($value)) { $value = Join-Path (Split-Path -Parent $path) $value }
        $cfg.$key = [IO.Path]::GetFullPath($value)
    }
    if ($cfg.StageRoot.StartsWith('\\') -or $cfg.LogRoot.StartsWith('\\')) { throw 'Stage and logs must be local.' }
    if ([IO.Path]::GetExtension($cfg.MasterCsv) -ne '.csv') { throw 'MasterCsv must end in .csv.' }
    $prefix = $cfg.InboxRoot.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    if ($cfg.MasterCsv.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Master CSV must be outside the inbox tree.' }
    foreach ($key in 'IncludeSerialNumber','IncludeIPv4') {
        if ($cfg.$key -isnot [bool]) { throw 'Optional field switches must be JSON booleans.' }
    }
    if ($cfg.ComputerIdentity -ne 'NetBIOSName') { throw 'Unsupported ComputerIdentity.' }
    foreach ($key in 'MaxRecordAgeDays','MaxFutureMinutes') {
        if ($cfg.$key -isnot [int] -or $cfg.$key -lt 0 -or $cfg.$key -gt 3650) { throw 'Invalid age or clock tolerance.' }
    }
    return $cfg
}

function Get-ComputerKey([string]$Name) {
    if ($Name -cnotmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]{0,13}[A-Za-z0-9])?$' -or $Name -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') { throw 'Invalid computer identifier.' }
    return $Name.ToUpperInvariant()
}

function Write-InventoryLog($Config,[string]$Kind,[string]$Code) {
    try {
        [void][IO.Directory]::CreateDirectory($Config.LogRoot)
        # One file per run avoids inter-process writes and never includes input or raw exceptions.
        $name = '{0}-{1}.log' -f $Kind,[guid]::NewGuid().ToString('N')
        [IO.File]::WriteAllText((Join-Path $Config.LogRoot $name),('{0:o} {1}' -f [DateTime]::UtcNow,$Code),$script:Utf8)
    } catch { Write-Warning 'Could not write the local status log.' }
}

function Get-InventoryFailureCode($Failure) {
    $cause = $Failure.Exception
    while ($cause.InnerException) { $cause = $cause.InnerException }
    if ($cause -is [UnauthorizedAccessException] -or $cause -is [Security.SecurityException]) { return 'ACCESS_DENIED' }
    if ($cause -is [IO.DirectoryNotFoundException] -or $cause -is [IO.FileNotFoundException]) { return 'PATH_UNAVAILABLE' }
    if ($cause -is [IO.IOException]) { return 'IO_OR_LOCK_FAILURE' }
    return 'CONFIGURATION_OR_VALIDATION_FAILURE'
}

function ConvertTo-SafeCell($Value) {
    $cell = ([string]$Value -replace '[\p{Cc}\p{Cf}]',' ').Trim()
    if ($cell.Length -gt 1024) { $cell = $cell.Substring(0,1024) }
    if ($cell -match '^[=+\-@]') { $cell = "'" + $cell }
    return $cell
}

function Assert-Record($Row,[string]$ExpectedId) {
    if (($Row.PSObject.Properties.Name -join ',') -cne ($script:Fields -join ',')) { throw 'CSV schema mismatch.' }
    if ($Row.SchemaVersion -cne '1' -or (Get-ComputerKey $Row.ComputerId) -cne $ExpectedId -or $Row.ComputerId -cne $ExpectedId) { throw 'Invalid schema or computer identity.' }
    $stamp = [DateTimeOffset]::ParseExact($Row.CollectedUtc,'o',$script:Invariant,[Globalization.DateTimeStyles]::None)
    if ($stamp.Offset -ne [TimeSpan]::Zero) { throw 'Timestamp must be UTC.' }
    foreach ($key in $script:Fields) {
        $cell = [string]$Row.$key
        if ($cell.Length -gt 1025 -or $cell -match '[\p{Cc}\p{Cf}]' -or $cell.TrimStart() -match '^[=+\-@]') { throw 'Unsafe field.' }
    }
    foreach ($key in 'RamGiB','FixedVolumeGiB') {
        if ($Row.$key -ne '' -and $Row.$key -cnotmatch '^\d{1,12}(\.\d{1,2})?$') { throw 'Invalid capacity.' }
    }
    return $stamp
}

function New-CsvLines([object[]]$Rows) {
    if ($Rows.Count -eq 0) { return '"' + ($script:Fields -join '","') + '"' }
    $Rows | Select-Object -Property $script:Fields | ConvertTo-Csv -NoTypeInformation
}

function Write-AtomicFile([string]$Path,[string[]]$Lines,[switch]$Replace,[string]$StagedFile) {
    $parent = Split-Path -Parent $Path
    # The final rename must occur on the same volume and in the same folder.
    $partial = Join-Path $parent ('.' + [guid]::NewGuid().ToString('N') + '.part')
    $stream = $null
    $owned = $false
    try {
        $stream = [IO.File]::Open($partial,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        $owned = $true
        if ($StagedFile) {
            $source = [IO.File]::OpenRead($StagedFile)
            try { $source.CopyTo($stream) } finally { $source.Dispose() }
        } else {
            $body = $script:Utf8.GetBytes(($Lines -join "`r`n") + "`r`n")
            $head = $script:Utf8.GetPreamble()
            $stream.Write($head,0,$head.Length)
            $stream.Write($body,0,$body.Length)
        }
        $stream.Flush($true)
        $stream.Dispose()
        $stream = $null
        if ($Replace -and [IO.File]::Exists($Path)) { [IO.File]::Replace($partial,$Path,[NullString]::Value) }
        else { [IO.File]::Move($partial,$Path) }
    } finally {
        if ($stream) { $stream.Dispose() }
        if ($owned -and [IO.File]::Exists($partial)) { try { [IO.File]::Delete($partial) } catch {} }
    }
}

function Read-Submission([string]$Path,[string]$Id) {
    Add-Type -AssemblyName Microsoft.VisualBasic
    $stream = [IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    $parser = $null
    try {
        if ($stream.Length -gt 65536) { throw 'Submission exceeds size limit.' }
        $parser = [Microsoft.VisualBasic.FileIO.TextFieldParser]::new($stream,$script:Utf8,$true,$true)
        $parser.SetDelimiters(',')
        $parser.TrimWhiteSpace = $false
        $header = $parser.ReadFields()
        if (($header -join [char]31) -cne ($script:Fields -join [char]31)) { throw 'CSV schema mismatch.' }
        $values = $parser.ReadFields()
        if ($null -eq $values -or $values.Count -ne $script:Fields.Count -or !$parser.EndOfData) { throw 'Expected one complete record.' }
        $data = [ordered]@{}
        for ($i=0; $i -lt $header.Count; $i++) { $data[$header[$i]] = $values[$i] }
        $row = [pscustomobject]$data
        $stamp = Assert-Record $row $Id
        return [pscustomobject]@{ Row=$row; Stamp=$stamp }
    } finally {
        if ($parser) { $parser.Dispose() }
        $stream.Dispose()
    }
}

