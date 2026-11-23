[CmdletBinding()]
param([string]$ConfigPath = (Join-Path $PSScriptRoot 'inventory.config.json'))
. (Join-Path $PSScriptRoot 'Inventory-Common.ps1')

function Get-LocalInventory($Config) {
    $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $cpu = @(Get-CimInstance Win32_Processor -ErrorAction Stop)
    $volumes = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop)
    $serial = ''
    $ipv4 = ''
    if ($Config.IncludeSerialNumber) {
        $serial = (Get-CimInstance Win32_BIOS -ErrorAction Stop).SerialNumber
    }
    if ($Config.IncludeIPv4) {
        $ipv4 = @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' -ErrorAction Stop |
            ForEach-Object { $_.IPAddress } | Where-Object { $_ -match '^(?:\d{1,3}\.){3}\d{1,3}$' } | Sort-Object -Unique) -join '; '
    }
    $disk = ($volumes | Measure-Object -Property Size -Sum).Sum
    [ordered]@{
        Manufacturer=$computer.Manufacturer; Model=$computer.Model; SerialNumber=$serial
        Processor=($cpu.Name -join '; ')
        RamGiB=([math]::Round($computer.TotalPhysicalMemory / 1GB,2)).ToString($script:Invariant)
        FixedVolumeGiB=([math]::Round($disk / 1GB,2)).ToString($script:Invariant)
        OsCaption=$os.Caption; OsVersion=$os.Version; IPv4=$ipv4
    }
}

function Submit-Inventory($Config,[string]$ComputerName,[scriptblock]$Provider) {
    $id = Get-ComputerKey $ComputerName
    $deviceFolder = Join-Path $Config.InboxRoot $id
    $device = Get-Item -LiteralPath $deviceFolder -ErrorAction Stop
    if (!$device.PSIsContainer -or ($device.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Invalid device folder.' }
    $data = & $Provider $Config
    $row = [ordered]@{ SchemaVersion='1'; ComputerId=$id; CollectedUtc=[DateTimeOffset]::UtcNow.ToString('o',$script:Invariant) }
    foreach ($key in $script:Fields[3..($script:Fields.Count-1)]) {
        $row[$key] = if (($key -eq 'SerialNumber' -and !$Config.IncludeSerialNumber) -or
            ($key -eq 'IPv4' -and !$Config.IncludeIPv4)) { '' } else { ConvertTo-SafeCell $data[$key] }
    }
    $record = [pscustomobject]$row
    [void](Assert-Record $record $id)
    $name = 'submission-' + [guid]::NewGuid().ToString('N') + '.csv'
    [void][IO.Directory]::CreateDirectory($Config.StageRoot)
    $staged = Join-Path $Config.StageRoot $name
    Write-AtomicFile $staged @(New-CsvLines @($record))
    try { Write-AtomicFile (Join-Path $deviceFolder $name) @() -StagedFile $staged }
    finally { try { [IO.File]::Delete($staged) } catch {} }
}

if ($MyInvocation.InvocationName -ne '.') {
    $cfg = $null
    try {
        $cfg = Read-InventoryConfig $ConfigPath
        Submit-Inventory $cfg $env:COMPUTERNAME { param($c) Get-LocalInventory $c }
        Write-InventoryLog $cfg 'collect' 'SUBMITTED'
        Write-Output 'Inventory submitted.'
        exit 0
    } catch {
        $code = Get-InventoryFailureCode $_
        if ($cfg) { Write-InventoryLog $cfg 'collect' $code }
        Write-Error "Collection failed ($code). Check the local log, paths and execution identity." -ErrorAction Continue
        exit 1
    }
}
