# Changelog

## 1.0.0

- Introduces a configurable Windows PowerShell 5.1 collector and server merger.
- Separates submissions and master CSV, publishes by rename or replacement, and prevents overlapping merge jobs.
- Validates the schema and computer identity, and uses deterministic latest-record selection.
- Minimizes collected fields, adds safe CSV cells and local status logs.
- Includes offline tests, a fictional sample, and documented startup and logon paths.
