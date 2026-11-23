# Start here

Open **Windows PowerShell** and change to the extracted toolkit folder. Start with the bundled sample so you can see a complete result without a server.

```powershell
New-Item -ItemType Directory -Force .\_data\inbox\PC-001, .\_data\master | Out-Null
Copy-Item .\Samples\submission-00000000000000000000000000000001.csv .\_data\inbox\PC-001\
.\Merge-InventoryCSV.ps1
Import-Csv .\_data\master\MasterInventory.csv | Format-Table
```

For a real local test, create a folder under the inbox named exactly for your computer, then run the collector.

```powershell
New-Item -ItemType Directory -Force (Join-Path .\_data\inbox $env:COMPUTERNAME) | Out-Null
.\Collect-FullInventory.ps1
.\Merge-InventoryCSV.ps1
```

Open the master in Excel using **Data > From Text/CSV**, choose UTF-8 and comma, and import identifier and serial columns as text. Close Excel before replacing a master that it holds open. Keep test output private.

Run the offline suite with `powershell.exe -NoProfile -File .\Tests\Run-OfflineTests.ps1`. Follow organizational script signing and execution policy.
