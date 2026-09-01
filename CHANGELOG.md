# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `sensors` command: temperatures, fan speeds, voltages, currents and
  power draw from `/sys/class/hwmon` (the same source `lm-sensors`
  reads), with optional labels and max/critical thresholds. Included
  in `ninfo` (all) and `ninfo --json` output. Machines without hwmon
  (containers, some VMs) report an empty section, not an error.

## [0.1.0] - 2026-08-31

### Added

- `ninfo` CLI with `system`, `cpu`, `memory`, `storage`, `network` and
  `processes` commands, plus a no-command "show everything" mode.
- Global options: `--json`, `--plain`, `--no-color`, `--help`, `--version`.
- Collectors using native Linux interfaces only (`/proc`, `/sys`,
  `uname(2)`, `statvfs(2)`, `getifaddrs(3)`, `sysconf(3)`) — no external
  commands, no root privileges.
- Deterministic JSON output with `null` for unavailable values.
- Terminal renderer with ANSI colors and narrow-terminal-friendly layout.
- Meaningful exit codes: 0 success, 1 runtime error, 2 usage error.
- 77 unit tests and 20 CLI integration tests.
- Documentation: README, architecture and usage guides.

[Unreleased]: https://github.com/bisug/ninfo/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/bisug/ninfo/releases/tag/v0.1.0
