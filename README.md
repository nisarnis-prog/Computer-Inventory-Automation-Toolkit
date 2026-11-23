# Computer Inventory Automation Toolkit

A Windows PowerShell 5.1 toolkit for collecting basic PC hardware and OS inventory through Active Directory Group Policy and merging CSV submissions on a file server.

A client writes one completed, uniquely named record into its own pre-provisioned inbox folder. The server selects one latest valid record per computer and atomically publishes the master outside the inbox. Collection runs again safely. Repeated merges over unchanged inputs produce the same CSV bytes.

Serial numbers and IPv4 addresses are disabled by default. Employee names, account names, MAC addresses, LDAP data and credentials are outside the schema. The built-in identity is a unique Windows computer name within one inventory scope.

- [Start here](START-HERE.md)
- [Installation](INSTALLATION-GUIDE.md) and [configuration](CONFIGURATION-GUIDE.md)
- [Group Policy deployment](GROUP-POLICY-DEPLOYMENT.md)
- [Security](SECURITY.md) and [troubleshooting](TROUBLESHOOTING.md)
- [Release notes](CHANGELOG.md)

The offline suite exercises the collector with fictional data and filesystem fixtures. Validate GPO, SMB ACLs and CIM availability in a lab before rollout. Windows PowerShell 5.1 and an NTFS server-side master volume are the supported baseline.

Maintainer: Nisar Muhammad. MIT license.
