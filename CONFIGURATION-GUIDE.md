# Configuration guide

The bundled `inventory.config.json` uses relative local paths. Use a protected configuration per role. Scripts take `-ConfigPath`; the batch wrapper uses a file named `inventory.config.json` beside it. Relative paths resolve from the configuration file's directory. Escape backslashes in JSON strings.

| Setting | Meaning |
|---|---|
| InboxRoot | Client UNC inbox or server local inbox, containing pre-created device folders such as PC-001. The default is _data/inbox. |
| StageRoot | Local writable staging directory. A folder is created if needed. |
| LogRoot | Local writable directory for one small status log per run. |
| MasterCsv | Full or config-relative CSV path outside the entire inbox tree. Create its parent first. The merge role uses this setting. |
| ComputerIdentity | NetBIOSName. The computer name is normalized to uppercase and must be unique across this inbox. Use separate inboxes for overlapping domains. |
| IncludeSerialNumber | Boolean. Defaults to false. Enable only when authorized. |
| IncludeIPv4 | Boolean. Defaults to false. Enable only when authorized. |
| MaxRecordAgeDays | Zero disables age filtering. Positive values omit expired input from the next nonempty merge. An empty result retains an existing master. |
| MaxFutureMinutes | Maximum future client UTC skew accepted at merge. Default 10. Keep clocks synchronized. |

The newest valid CollectedUtc wins per normalized name. Equal timestamps are resolved by ordinal descending submission filename. Renames appear as new computer identities. Retire the old inbox manually. Required schema columns are stable, and unavailable optional values are blank. FixedVolumeGiB sums fixed logical volumes and is not a physical drive or SSD health report.

The master is rebuilt from the inbox snapshot and sorted by computer name. During a merge, a newly committed submission may be picked up on the next run. An inaccessible folder or an I/O error aborts the merge. Malformed inputs are counted and skipped if the device still has a valid surviving submission. The run aborts if malformed records leave a populated device without a valid surviving submission.
