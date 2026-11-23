$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. "$root/Collect-FullInventory.ps1"
. "$root/Merge-InventoryCSV.ps1"
$temp = Join-Path ([IO.Path]::GetTempPath()) ('inventory-tests-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($temp)
$failed=0
$passed=0
$skipped=0
function Assert($condition,[string]$text='Assertion failed') { if (!$condition) { throw $text } }
function Reject([scriptblock]$Action) {
    $rejected=$false
    try { & $Action | Out-Null } catch { $rejected=$true }
    Assert $rejected 'Expected rejection.'
}
function Test-Case([string]$Name,[scriptblock]$Body) {
    try { & $Body; $script:passed++; Write-Output "PASS $Name" }
    catch { $script:failed++; Write-Output "FAIL $Name : $($_.Exception.Message)"; Write-Output $_.ScriptStackTrace }
}
function New-Scenario {
    $base=Join-Path $temp ([guid]::NewGuid().ToString('N'))
    $device=Join-Path $base 'inbox/PC-001'
    [void][IO.Directory]::CreateDirectory($device)
    [void][IO.Directory]::CreateDirectory((Join-Path $base 'master'))
    $path=Join-Path $base 'test.json'
    Copy-Item "$root/inventory.config.json" $path
    $cfg=Read-InventoryConfig $path
    # Override the local default tree for this scenario.
    $cfg.InboxRoot=Join-Path $base 'inbox'
    $cfg.StageRoot=Join-Path $base 'stage'
    $cfg.LogRoot=Join-Path $base 'logs'
    $cfg.MasterCsv=Join-Path $base 'master/MasterInventory.csv'
    return $cfg
}
$mock={ param($cfg)
    @{Manufacturer='Contoso';Model='Desk 1';SerialNumber='DEMO-001';Processor='Example CPU';RamGiB='16';FixedVolumeGiB='512';OsCaption='Windows 11';OsVersion='10.0';IPv4='192.0.2.10'}
}
function Submit($cfg) { Submit-Inventory $cfg 'PC-001' $mock }
function Read-Master($cfg) { Import-Csv -LiteralPath $cfg.MasterCsv -Encoding UTF8 }
function Device($cfg) { Join-Path $cfg.InboxRoot 'PC-001' }
function Add-Bad($cfg,[string[]]$Text) {
    $name='submission-'+[guid]::NewGuid().ToString('N')+'.csv'
    [IO.File]::WriteAllLines((Join-Path (Device $cfg) $name),$Text)
}
try {
    Test-Case '01 fresh mocked collection and private defaults' {
        $c=New-Scenario; Submit $c
        $f=Get-ChildItem (Device $c) -Filter '*.csv'
        $r=(Read-Submission $f.FullName 'PC-001').Row
        Assert ($r.Model -eq 'Desk 1' -and !$r.SerialNumber -and !$r.IPv4)
    }
    Test-Case '02 repeated collection' {
        $c=New-Scenario; Submit $c; Submit $c
        Assert (@(Get-ChildItem (Device $c) -Filter '*.csv').Count -eq 2)
        Merge-Inventory $c | Out-Null
        Assert (@(Read-Master $c).Count -eq 1)
    }
    Test-Case '03 duplicate timestamps and deterministic filename tie-break' {
        $c=New-Scenario; Submit $c
        $f=Get-ChildItem (Device $c) -Filter '*.csv'
        $r=(Read-Submission $f.FullName 'PC-001').Row
        $r.Model='Winner'
        Write-AtomicFile (Join-Path (Device $c) ('submission-'+('f'*32)+'.csv')) @(New-CsvLines @($r))
        Merge-Inventory $c | Out-Null
        Assert ((Read-Master $c).Model -eq 'Winner')
    }
    Test-Case '04 prior master and stray input CSV ignored' {
        $c=New-Scenario; Submit $c
        Set-Content -LiteralPath $c.MasterCsv 'OLD'
        Set-Content -LiteralPath (Join-Path $c.InboxRoot 'MasterInventory.csv') 'STRAY'
        Merge-Inventory $c | Out-Null
        Assert (@(Read-Master $c).Count -eq 1)
    }
    Test-Case '05 empty inbox creates header and preserves existing master' {
        $c=New-Scenario; Merge-Inventory $c | Out-Null
        Assert (@(Read-Master $c).Count -eq 0)
        $h=(Get-FileHash $c.MasterCsv).Hash; Merge-Inventory $c | Out-Null
        Assert ((Get-FileHash $c.MasterCsv).Hash -eq $h)
    }
    Test-Case '06 missing inbox and missing submission leave master intact' {
        $c=New-Scenario; Submit $c; Merge-Inventory $c | Out-Null
        $h=(Get-FileHash $c.MasterCsv).Hash
        $c.InboxRoot=Join-Path $temp 'missing'
        Reject { Merge-Inventory $c }
        Reject { Read-Submission (Join-Path $temp 'missing.csv') 'PC-001' }
        Assert ((Get-FileHash $c.MasterCsv).Hash -eq $h)
    }
    Test-Case '07 malformed CSV fails closed when no valid record remains' {
        $c=New-Scenario
        Add-Bad $c @((New-CsvLines @()),'"unterminated')
        Reject { Merge-Inventory $c }
        Assert (!(Test-Path $c.MasterCsv))
    }
    Test-Case '08 inconsistent headers are skipped alongside valid input' {
        $c=New-Scenario; Submit $c
        Add-Bad $c @('Name,CPU','PC-001,Example')
        Assert ((Merge-Inventory $c) -match 'invalid=1')
    }
    Test-Case '09 denied file access classification and preservation' {
        $c=New-Scenario; Submit $c; Merge-Inventory $c | Out-Null
        $h=(Get-FileHash $c.MasterCsv).Hash
        $item=Get-Item $c.MasterCsv
        $item.IsReadOnly=$true
        try { Reject { Merge-Inventory $c } }
        finally { (Get-Item $c.MasterCsv).IsReadOnly=$false }
        Assert ((Get-FileHash $c.MasterCsv).Hash -eq $h)
        try {throw [UnauthorizedAccessException]::new('simulated')} catch {
            Assert ((Get-InventoryFailureCode $_) -eq 'ACCESS_DENIED')
        }
    }
    Test-Case '10 unavailable share path simulated offline' {
        $c=New-Scenario; $c.InboxRoot=Join-Path $temp 'offline-share-simulation'
        Reject { Submit $c }
        Assert (!(Test-Path $c.StageRoot))
    }
    Test-Case '11 overlapping merge lock and submission during server lock' {
        $c=New-Scenario; Submit $c
        $lock=[IO.File]::Open($c.MasterCsv+'.lock','OpenOrCreate','ReadWrite','None')
        try {
            Reject { Merge-Inventory $c }
            $workers=@()
            try {
                $work={
                    param($project,$cfg)
                    . "$project/Collect-FullInventory.ps1" -ConfigPath "$project/inventory.config.json"
                    Submit-Inventory $cfg 'PC-001' {
                        param($settings)
                        @{Manufacturer='Contoso';Model='Desk 1';SerialNumber='';Processor='Example CPU';RamGiB='16';FixedVolumeGiB='512';OsCaption='Windows 11';OsVersion='10.0';IPv4=''}
                    }
                }
                foreach ($i in 1..2) {
                    $worker=[PowerShell]::Create()
                    [void]$worker.AddScript($work.ToString()).AddParameter('project',$root).AddParameter('cfg',$c)
                    $workers+=@(@{Shell=$worker;Run=$worker.BeginInvoke()})
                }
                foreach ($worker in $workers) {
                    $null=$worker.Shell.EndInvoke($worker.Run)
                    Assert (!$worker.Shell.HadErrors) ($worker.Shell.Streams.Error -join '; ')
                }
            } finally { foreach ($worker in $workers) { $worker.Shell.Dispose() } }
        }
        finally { $lock.Dispose() }
        Merge-Inventory $c | Out-Null
        Assert (@(Get-ChildItem (Device $c) -Filter '*.csv').Count -eq 3)
        Assert (@(Read-Master $c).Count -eq 1)
    }
    Test-Case '12 interrupted partial ignored and failed replacement retains master' {
        $c=New-Scenario; Submit $c; Merge-Inventory $c | Out-Null
        $h=(Get-FileHash $c.MasterCsv).Hash
        Set-Content -LiteralPath (Join-Path (Device $c) '.crash.part') 'INTERUPTED'
        $open=[IO.File]::Open($c.MasterCsv,'Open','Read','Read')
        try { Reject { Merge-Inventory $c } } finally { $open.Dispose() }
        Merge-Inventory $c | Out-Null
        Assert ((Get-FileHash $c.MasterCsv).Hash -eq $h)
    }
    Test-Case '13 Windows PowerShell 5.1 runtime and parser' {
        Assert ($PSVersionTable.PSEdition -eq 'Desktop' -and $PSVersionTable.PSVersion.ToString().StartsWith('5.1.'))
        foreach($f in Get-ChildItem $root -Recurse -Filter '*.ps1'){
            $tokens=$null;$errors=$null
            [void][Management.Automation.Language.Parser]::ParseFile($f.FullName,[ref]$tokens,[ref]$errors)
            Assert ($errors.Count -eq 0) "Parser rejected $($f.Name)"
        }
    }
    Test-Case '14 privacy defaults and formula protection' {
        $c=New-Scenario; Submit $c; Merge-Inventory $c | Out-Null
        $r=Read-Master $c
        Assert (!$r.SerialNumber -and !$r.IPv4 -and $r.PSObject.Properties.Name -notcontains 'UserName')
        Assert ((ConvertTo-SafeCell '=1+2') -eq "'=1+2")
        Assert ((ConvertTo-SafeCell '@example') -eq "'@example")
        $spoof=$r.PSObject.Copy();$spoof.ComputerId='PC-002'
        Reject { Assert-Record $spoof 'PC-001' }
    }
    Test-Case '15 idempotent merge exact file bytes' {
        $c=New-Scenario; Submit $c; Merge-Inventory $c | Out-Null
        $h=(Get-FileHash $c.MasterCsv).Hash; Merge-Inventory $c | Out-Null
        Assert ((Get-FileHash $c.MasterCsv).Hash -eq $h)
    }
    Write-Output 'SKIP live AD, GPO, SMB, and endpoint CIM tests. Offline suite uses test data and local files.'
    $skipped++
    Write-Output "TOTAL PASS=$passed FAIL=$failed SKIP=$skipped"
} finally {
    # Only the unique fixture directory created by this test runner is removed.
    $resolved=(Resolve-Path -LiteralPath $temp).Path
    if ($resolved -eq [IO.Path]::GetFullPath($temp) -and (Split-Path -Leaf $resolved) -match '^inventory-tests-[a-f0-9]{32}$') {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
if ($failed -gt 0) { exit 1 }




