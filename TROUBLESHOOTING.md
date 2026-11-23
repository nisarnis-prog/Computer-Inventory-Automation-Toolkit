# Troubleshooting

| Symptom | Check |
|---|---|
| Collection reports PATH_UNAVAILABLE | The share may be offline or the device folder is missing. Check connectivity and exact computer name. Launch from an authorized identity. |
| ACCESS_DENIED or a blocked launcher | Check share and NTFS rights under the identity that actually ran the script. Verify script-signing requirements and any endpoint application controls. |
| IO_OR_LOCK_FAILURE | Check an overlapping merge, a master held by Excel, and server disk space. Close the reader and rerun. |
| CONFIGURATION_OR_VALIDATION_FAILURE | Validate JSON, check all paths and schema fields, and verify timestamps use UTC. Compare a sample file's headers. |
| Master has old data | Verify the server scheduler, the local status log, authorized folder reads, timestamp skew and age settings. An empty result retains the existing master. |
| Two devices share a name | Use separate inboxes. A rename creates another ID. Retire the old folder after verifying the new submission. |
| Excel changes serials | Import from Text/CSV as UTF-8 and set identifiers to text. |
| Old .part files | A client or server may have stopped mid-write. The merger ignores them. Remove stale partials through controlled maintenance outside run windows. |

Check permissions and connectivity in a lab before deploying to a live OU.
