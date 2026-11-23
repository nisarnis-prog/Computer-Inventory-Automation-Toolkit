# Computer Inventory Automation Toolkit

A Windows PowerShell 5.1 toolkit for collecting basic PC hardware and OS inventory through Active Directory Group Policy and merging CSV submissions on a file server.

> [!IMPORTANT]
> **Important: Read the [Safety Precautions, User Responsibilities & Limitation of Liability section](#safety-precautions-user-responsibilities--limitation-of-liability) and the [MIT License](LICENSE) before downloading, configuring, or deploying this toolkit. Always test in a non-production environment first.**

### Download & Getting Started

**New to PowerShell or Group Policy? Start with the Beginner PDF Manual.**

1. [Download Beginner PDF Manual](https://raw.githubusercontent.com/nisarnis-prog/Computer-Inventory-Automation-Toolkit/main/Documentation/Computer-Inventory-Automation-Toolkit-Beginners-Guide-v1.0.0.pdf)
2. [Download Toolkit ZIP v1.0.0](https://github.com/nisarnis-prog/Computer-Inventory-Automation-Toolkit/releases/download/v1.0.0/Computer-Inventory-Automation-Toolkit-v1.0.0.zip)
3. [Read the online setup instructions](START-HERE.md)

A client writes one completed, uniquely named record into its own pre-provisioned inbox folder. The server selects one latest valid record per computer and atomically publishes the master outside the inbox. Collection runs again safely. Repeated merges over unchanged inputs produce the same CSV bytes.

Serial numbers and IPv4 addresses are disabled by default. Employee names, account names, MAC addresses, LDAP data and credentials are outside the schema. The built-in identity is a unique Windows computer name within one inventory scope.

- [Start here](START-HERE.md)
- [Installation](INSTALLATION-GUIDE.md) and [configuration](CONFIGURATION-GUIDE.md)
- [Group Policy deployment](GROUP-POLICY-DEPLOYMENT.md)
- [Security](SECURITY.md) and [troubleshooting](TROUBLESHOOTING.md)
- [Release notes](CHANGELOG.md)

The offline suite exercises the collector with fictional data and filesystem fixtures. Validate GPO, SMB ACLs and CIM availability in a lab before rollout. Windows PowerShell 5.1 and an NTFS server-side master volume are the supported baseline.

Maintainer: Nisar Muhammad. MIT license.

## Safety Precautions, User Responsibilities & Limitation of Liability

### Safety Precautions

This toolkit is intended for educational, testing, and authorized IT administration purposes.

Before using or deploying this toolkit:

1. Test all scripts in a controlled lab or test environment before production deployment.
2. Review and customize all configuration settings, including server paths, network shares, folder permissions, and Group Policy settings.
3. Ensure that you have appropriate authorization to run scripts and modify configurations within your organization.
4. Back up relevant configurations, inventory data, and systems before making changes.
5. Verify SMB share permissions, NTFS permissions, and script execution policies.
6. Deploy initially to a limited number of test computers and verify the results.
7. Review all scripts and documentation to ensure compatibility with your environment.
8. Follow your organization's security policies, data protection requirements, and applicable laws.

### User Responsibilities

Users and system administrators are solely responsible for:

- Reviewing and understanding the scripts before execution.
- Configuring the toolkit correctly for their own environment.
- Testing and validating the scripts before production use.
- Ensuring appropriate permissions, security controls, backups, and monitoring.
- Obtaining organizational authorization before deployment.
- Protecting collected computer inventory information.
- Evaluating compatibility with their systems and infrastructure.
- Maintaining and troubleshooting their own deployment.

### Disclaimer & Limitation of Liability

**THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT.**

**TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THE AUTHOR AND COPYRIGHT HOLDERS SHALL NOT BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY ARISING FROM OR IN CONNECTION WITH THE SOFTWARE OR ITS USE, INCLUDING BUT NOT LIMITED TO DATA LOSS, SYSTEM DISRUPTION, SERVICE INTERRUPTION, SECURITY INCIDENTS, MISCONFIGURATION, OR OTHER DIRECT OR INDIRECT LOSSES.**

Users assume responsibility for evaluating, configuring, testing, and deploying the toolkit within their own environments.

This disclaimer is intended to be consistent with the MIT License and does not override any rights or obligations that cannot legally be excluded.

### License

This project is distributed under the MIT License.

See the repository's [LICENSE](LICENSE) file for the complete license terms.
