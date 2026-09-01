# ninfo

A Linux system information CLI with one job: **a whole-system snapshot as
JSON in a single call**.

```sh
ninfo --json | jq '.memory.used_percent'
```

`ninfo` collects system, CPU, memory, storage, network and process data
through native Linux interfaces (`/proc`, `/sys`, `uname(2)`, `statvfs(2)`,
`getifaddrs(3)`) — it never shells out to external commands, needs no root
privileges, and outputs one deterministic schema.

## Why ninfo

For a human-readable glance at one thing, the built-ins are better:
`lscpu`, `free -h`, `df -h`, `ip addr`. Use those.

ninfo earns its install when you want **everything, machine-readable, at
once**:

| Need | Built-ins | ninfo |
|------|-----------|-------|
| One field, human-readable | ✅ `free -h` | ❌ |
| Whole system, pretty text | `fastfetch` | ❌ |
| Whole system, one JSON call | 6+ calls, no JSON from `free`/`df`/`ps`, mixed schemas | ✅ |

Typical users:

- **Status bars / scripts** — one `jq` filter instead of parsing six text formats
- **CI runners, provisioning** — snapshot machine state to a log or DB in one line
- **Minimal systems** — single static binary, no Python (glances) or Node runtime

## Features

- **System** — OS name, kernel version, architecture, hostname, uptime
- **CPU** — model, physical/logical core counts, max frequency
- **Memory** — total/used/available RAM, usage percentage, swap
- **Storage** — mounted filesystems with capacity and usage
- **Network** — interfaces, IPv4/IPv6/MAC addresses, default gateway
- **Processes** — total, running, sleeping and zombie counts
- **Sensors** — temperatures, fans, voltages from `/sys/class/hwmon`
- **Battery** — charge, state, voltage, health from `/sys/class/power_supply`
- **Three output formats** — colored terminal, plain text, deterministic JSON
- **No root required** — everything works as an unprivileged user
- **No dependencies** — Nim standard library only, single static binary

## Installation

### One-line install

```sh
curl -fsSL https://raw.githubusercontent.com/bisug/ninfo/main/install.sh | bash
```

Installs to `~/.local/bin` (override with `--prefix DIR`). Builds from
source when a Nim toolchain is present, otherwise downloads a release
binary. Uninstall with `install.sh --uninstall`.

### From source

Requires [Nim](https://nim-lang.org) 2.2 or later.

```sh
git clone https://github.com/bisug/ninfo.git
cd ninfo
nimble build        # produces bin/ninfo
sudo cp bin/ninfo /usr/local/bin/   # optional
```

### Verify

```sh
ninfo --version
```

## Usage

```
Usage: ninfo [command] [options]

Commands:
  system     Operating system, kernel, architecture, hostname, uptime
  cpu        CPU model, core counts, frequency
  memory     RAM and swap usage
  storage    Mounted filesystems and capacity
  network    Interfaces, addresses, default gateway
  processes  Process counts
  sensors    Hardware temperatures, fans, voltages
  battery    Battery charge, state and health
  help       Show this help
  version    Show version

Options:
  --json       Output JSON (script-friendly, deterministic)
  --plain      Plain text: no colors, no box drawing
  --no-color   Disable ANSI colors (keeps layout)
  -h, --help   Show this help
  -v, --version  Show version
```

### Examples

Show everything:

```sh
ninfo
```

```
System
OS: Fedora Linux 40
Kernel: 6.10.5-100.fc40.x86_64
Architecture: x86_64
Hostname: myhost
Uptime: 3d 4h 12m

CPU
Model: AMD Ryzen 5 5600X 6-Core Processor
Physical cores: 6
Logical cores: 12
Frequency: 4650.0 MHz

Memory
Total: 31.2 GiB
Used: 12.4 GiB
Available: 18.8 GiB
Usage: 39.7%
Swap total: 8.0 GiB
Swap used: 512.0 MiB
...
```

One section as JSON:

```sh
ninfo memory --json
```

```json
{
  "total_bytes": 33522163712,
  "used_bytes": 13324296192,
  "available_bytes": 20197867520,
  "used_percent": 39.7,
  "swap_total_bytes": 8589934592,
  "swap_used_bytes": 536870912
}
```

Use in a script:

```sh
total=$(ninfo memory --json | jq -r '.total_bytes')
echo "Total RAM: $total bytes"
```

Snapshot a whole machine to a file (the original use case):

```sh
ninfo --json > "snapshot-$(hostname)-$(date +%F).json"
```

Pipe to a file without colors:

```sh
ninfo --plain > system-report.txt
```

### Exit codes

| Code | Meaning |
|------|---------|
| 0    | Success |
| 1    | Runtime error (data could not be collected) |
| 2    | Usage error (bad command or option) |

## Development

```sh
nimble test          # run unit tests
nimble integration   # build binary + run CLI integration tests
nimble build          # release build to bin/ninfo
```

### Project layout

```
src/
  ninfo.nim           # entry point
  ninfo/
    cli/              # argument parsing, dispatch
    core/             # shared domain types
    system/           # OS/kernel/hostname/uptime collector
    hardware/         # CPU and memory collectors
    storage/          # filesystem collector
    network/          # interface collector
    process/          # process statistics
    output/           # text and JSON renderers
    utils/            # formatting helpers
tests/
  unit/               # pure-logic tests
  integration/        # CLI end-to-end tests
docs/
  architecture.md
  usage.md
```

See [docs/architecture.md](docs/architecture.md) for design details and
[docs/usage.md](docs/usage.md) for the full command reference.

## Testing

The test suite has 77 unit tests and 20 integration tests:

```sh
nimble test
nimble integration
```

Unit tests cover parsing and formatting logic (meminfo computation, mountinfo
parsing, byte/uptime formatting, CLI parsing, JSON shape). Integration tests
run the real binary and verify output, exit codes and error handling.

## Architecture

Collectors and renderers are strictly separated:

- **Collectors** read `/proc`, `/sys` and call native libc APIs. They return
  strongly-typed domain objects (`SystemInfo`, `CpuInfo`, ...) where
  unavailable values are `Option[T]`, never guesses.
- **Renderers** take those objects and produce terminal or JSON output. They
  never touch the filesystem.

This keeps presentation testable and makes adding a new output format a
single-file change. See [docs/architecture.md](docs/architecture.md).

## License

MIT — see [LICENSE](LICENSE).
