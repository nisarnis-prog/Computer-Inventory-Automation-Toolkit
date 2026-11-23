# Troubleshooting

The launcher follows Windows PowerShell execution policy. If policy or an application control prevents the script from starting, it may show a PowerShell error before a toolkit status code can be logged. Follow your organization's signing and deployment process.

| Symptom | What it means and what to check |
|---|---|
| `PATH_UNAVAILABLE` | A filesystem operation reported a missing file or directory. Check the configured paths, SMB connectivity, and whether a file disappeared during the operation. Windows PowerShell can report some missing paths using a different exception and status. |
| `ACCESS_DENIED` | The underlying operation raised an access or security exception. Verify the actual running identity and the required share and NTFS permissions. |
| `IO_OR_LOCK_FAILURE` | A filesystem I/O error occurred, including possible lock contention. Check overlapping merge jobs, Excel holding the master open, available disk space, and storage or SMB errors. Release any conflicting handle before rerunning. |
| `CONFIGURATION_OR_VALIDATION_FAILURE` | A missing device folder produces this code when the collector's Windows PowerShell 5.1 lookup raises an item-not-found error. Pre-create the computer-named folder inside the configured inbox. Also check JSON, unsupported settings, configured paths, CSV headers and UTC timestamps. The code is the fallback for other unclassified failures. |
| Master has old data | Check the server schedule, local status logs, readable submissions, timestamp skew, and age settings. An empty merge retains an existing master. |
| Two devices share a name | Use separate inboxes. A rename creates another ID. Retire the old folder after verifying the new submission. |
| Excel changes serials | Import from Text/CSV as UTF-8 and set identifiers to text. |
| Old .part files | A client or server may have stopped mid-write. The merger ignores them. Remove stale partials through controlled maintenance outside run windows. |

Check permissions and connectivity in a lab before deploying to a live OU.
