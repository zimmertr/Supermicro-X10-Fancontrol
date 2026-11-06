# Supermicro-X10-Fancontrol

A shell script, `fancontrol`, and its systemd unit, `fancontrol.service`, that set a Supermicro X10 server's fan duty cycle from the CPU temperature. The README explains the maths, the variables and the install steps.

This repo took a trimmed set of the files a new project starts with (zimmertr/yggdrasil record 0038). When a change here makes a decision, write its record; when it needs `CONTRIBUTING.md` or a `docs/` page, add it in the same PR.

## Rules

- Never run the script, `ipmitool` or anything else against a real server without TJ's okay. A bad duty cycle can overheat it. Work in a fresh clone in the session's scratchpad, never in TJ's checkout, and never push to main.
- The README is TJ's: keep it accurate and in his voice, and never restructure it.
- zimmertr/Bootstrap-Proxmox downloads `fancontrol` and `fancontrol.service` from `main`, so a merge here reaches the server the next time that role runs.
- CI is zimmertr/yggdrasil's `pr-title` and `lint` modules, pinned by commit SHA with the version beside it. Dependabot bumps the pin, and a patch or minor merges itself after three days. The PR title is `type(scope): summary`.

## Issues

File issues with the `create-issue` skill from zimmertr/ai-config. The skill reads the four things below from this section.

- **The reader**: TJ, who runs the server and knows IPMI and systemd.
- **The gates**: `PR Title / PR Title` and the three `Lint /` checks pass; the README stays accurate.
- **The constraints**: never run the script or `ipmitool` against a real server without TJ's okay; no secret values in the repo or in logs.
- **The areas**: `script` (`fancontrol`, `fancontrol.service`), `ci` (the workflows), `security`.
