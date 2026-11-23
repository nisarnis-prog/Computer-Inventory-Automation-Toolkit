# Security and privacy

## Isolate the writers

For startup clients, use computer-account security groups and assign each device's SMB identity NTFS permissions on its own pre-created folder only. On the share grant scoped submitters Change and the server operator appropriate access. Share access and NTFS both apply to remote access.

On the inbox root grant the client group only the traversal/read attributes needed for addressing child paths, scoped to this folder, with no generic inherited client Modify. In each device folder grant that device identity Modify so it can create, rename and clean up its own staging files. Keep the server merge identity able to traverse and read all submissions. Separate master rights from the inbox share. Review inherited ACEs and broad groups such as Authenticated Users and Creator Owner. Optional access-based enumeration helps hide folder listings. NTFS ACLs enforce the write boundary.

Test with two representative identities. Each must successfully submit and rename inside its assigned folder and fail to create, replace, rename or delete a file in the other folder or master. Validate the resulting ACLs and SMB behavior in a lab. Keep any offline client staging directory restricted to the collector identity and administrators.

## Trust and failure limits

Clients never choose an existing destination filename to overwrite. Submissions are written to a unique partial file in the destination folder, flushed and renamed without replacement. The merge ignores partials, verifies schema and identity, reads complete files through a shared read handle, locks concurrent server merges with an exclusive file handle, then publishes the master using a same-folder atomic rename or replacement. An interrupted operation may leave a partial file to clean up later. Use an NTFS server-side master and keep backups. Filesystem, SMB and endpoint-security implementations still affect guarantees.

A client with Modify can change or remove files in its own folder, forge its own hardware values, or skew timestamps within the allowed window. The merger verifies folder-to-record identity, not authenticity of hardware or time. Per-computer ACLs rely on correct provisioning and distinct principals. For stronger trust use authenticated server ingestion with server timestamps and immutable storage. Monitor retries, disk usage and the master age.

Use a dedicated merger account, restricted share access, signed script deployment where required, and SMB protection according to local policy. No execution policy bypass, directory lookups, stored credentials, user names, MAC addresses, or IP addresses by default. Hostnames can still be identifying and should be treated as internal data. Logs include only status and counts. Use trusted server storage, monitor volume capacity, and set a retention policy. Formula-like text is escaped at collection and rejected on import if unescaped.
