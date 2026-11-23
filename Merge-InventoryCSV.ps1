[CmdletBinding()]
param([string]$ConfigPath = (Join-Path $PSScriptRoot 'inventory.config.json'))
. (Join-Path $PSScriptRoot 'Inventory-Common.ps1')

function Merge-Inventory($Config,[DateTimeOffset]$Now = [DateTimeOffset]::UtcNow) {
    $master = $Config.MasterCsv
    # Never delete the lock file. Closing its handle releases the lock.
    $lock = [IO.File]::Open($master + '.lock',[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    try {
        $latest = @{}
        $invalid = 0
        $expired = 0
        $folders = @(Get-ChildItem -LiteralPath $Config.InboxRoot -Directory -ErrorAction Stop)
        foreach ($folder in $folders) {
            if ($folder.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
            try { $id = Get-ComputerKey $folder.Name } catch { continue }
            $files = @(Get-ChildItem -LiteralPath $folder.FullName -File -Filter 'submission-*.csv' -ErrorAction Stop)
            $invalidBefore = $invalid
            foreach ($file in $files) {
                if ($file.Name -cnotmatch '^submission-[a-f0-9]{32}\.csv$' -or
                    ($file.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                    $invalid++
                    continue
                }
                try {
                    $entry = Read-Submission $file.FullName $id
                    if ($entry.Stamp -gt $Now.AddMinutes($Config.MaxFutureMinutes)) { throw 'Future timestamp.' }
                } catch [UnauthorizedAccessException] { throw }
                  catch [IO.IOException] { throw }
                  catch { $invalid++; continue }
                if ($Config.MaxRecordAgeDays -gt 0 -and $entry.Stamp -lt $Now.AddDays(-$Config.MaxRecordAgeDays)) {
                    $expired++
                    continue
                }
                $current = $latest[$id]
                if (!$current -or $entry.Stamp -gt $current.Stamp -or
                    ($entry.Stamp -eq $current.Stamp -and [string]::CompareOrdinal($file.Name,$current.FileName) -gt 0)) {
                    $latest[$id] = @{ Row=$entry.Row; Stamp=$entry.Stamp; FileName=$file.Name }
                }
            }
            # Do not silently drop a previously known device because all its new input is bad.
            if ($files.Count -gt 0 -and !$latest[$id] -and $invalid -gt $invalidBefore) { throw 'No valid surviving record for a device with submissions.' }
        }
        if ($latest.Count -eq 0 -and [IO.File]::Exists($master)) { return "RETAINED_EMPTY expired=$expired" }
        $rows = @($latest.Keys | Sort-Object | ForEach-Object { $latest[$_].Row })
        Write-AtomicFile $master @(New-CsvLines $rows) -Replace
        return "MERGED records=$($rows.Count) invalid=$invalid expired=$expired"
    } finally { $lock.Dispose() }
}

if ($MyInvocation.InvocationName -ne '.') {
    $cfg = $null
    try {
        $cfg = Read-InventoryConfig $ConfigPath
        $summary = Merge-Inventory $cfg
        Write-InventoryLog $cfg 'merge' $summary
        Write-Output $summary
        exit 0
    } catch {
        $code = Get-InventoryFailureCode $_
        if ($cfg) { Write-InventoryLog $cfg 'merge' $code }
        Write-Error "Merge failed ($code). A prior master was retained if present." -ErrorAction Continue
        exit 1
    }
}

