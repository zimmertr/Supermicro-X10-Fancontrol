# Security Policy

## Supported Versions

There are no versions. `main` is the current script, and a fix ships as the next merge.

## Reporting a Vulnerability

Please report vulnerabilities privately through GitHub:
[Report a vulnerability](https://github.com/zimmertr/Supermicro-X10-Fancontrol/security/advisories/new).
Do not open a public issue for security problems.

Include what you found, where it lives (the script, the unit file, or a workflow), and how to reproduce it.

What to expect:

- **Acknowledgement** within a few days. This is a one-person project, so response times are best effort.
- **Fix**: a confirmed vulnerability is fixed in the next merge.
- **Credit** in the advisory, unless you'd rather not.

## Scope

In scope: the `fancontrol` script, `fancontrol.service` and the CI workflows. The script runs as root, so a flaw in how it handles sensor or IPMI output is the likeliest finding.

Out of scope: `ipmitool`, `lm-sensors`, `jq` and the BMC firmware. Report issues in those to their maintainers.

There is no bounty program. Reports are still appreciated.
