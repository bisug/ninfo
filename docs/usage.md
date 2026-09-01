# Usage

## Synopsis

```
ninfo [command] [options]
```

With no command, `ninfo` prints every section.

## Commands

### `ninfo system`

Operating system, kernel, architecture, hostname and uptime.

```
System
OS: Fedora Linux 40
Kernel: 6.10.5-100.fc40.x86_64
Architecture: x86_64
Hostname: myhost
Uptime: 3d 4h 12m
```

### `ninfo cpu`

CPU model, physical/logical core counts and maximum frequency.

```
CPU
Model: AMD Ryzen 5 5600X 6-Core Processor
Physical cores: 6
Logical cores: 12
Frequency: 4650.0 MHz
```

Physical cores are counted from sysfs topology (distinct package/core
pairs), which is correct on multi-socket systems where `/proc/cpuinfo`'s
`cpu cores` field is not.

### `ninfo memory`

RAM totals and swap.

```
Memory
Total: 31.2 GiB
Used: 12.4 GiB
Available: 18.8 GiB
Usage: 39.7%
Swap total: 8.0 GiB
Swap used: 512.0 MiB
```

"Used" matches `free(1)`'s modern semantics: total − `MemAvailable`.
Swap lines are omitted when no swap is configured.

### `ninfo storage`

Mounted filesystems with capacity. Pseudo filesystems (proc, sysfs,
tmpfs, ...) are excluded.

```
Storage
  Filesystem        Size      Used     Avail   Use%  Mounted on
  /dev/nvme0n1p2  931.5 GiB 412.7 GiB 471.9 GiB  46.6%  /
  /dev/nvme0n1p1  600.0 MiB 199.0 MiB 401.0 MiB  33.2%  /boot/efi
```

### `ninfo network`

Interfaces with addresses and the default gateway.

```
Network
  lo (up, loopback)
    IPv4: 127.0.0.1
    IPv6: ::1
    MAC: 00:00:00:00:00:00
  enp3s0 (up)
    IPv4: 10.0.0.42
    IPv6: fe80::5054:ff:fe9f:6a1b
    MAC: 52:54:00:9f:6a:1b
  Default gateway: 10.0.0.1
```

Interfaces without an address show `n/a`.

### `ninfo processes`

Process counts by state.

```
Processes
Total: 214
Running: 3
Sleeping: 148
Zombie: 0
```

### `ninfo sensors`

Hardware sensor readings from `/sys/class/hwmon` — the same source
`lm-sensors` reads, without shelling out. Grouped by chip; each line
shows the kernel label (or the sensor kind and number), the value in
human units, and the critical threshold when the chip exposes one.

```
Sensors
  coretemp
    Package id 0: 63.0 °C (crit 105.0 °C)
    Core 0: 63.0 °C (crit 105.0 °C)
  acpitz
    temp 1: 63.0 °C
```

Machines without hwmon (containers, some VMs) print `(no sensors)`.
Sensor kinds: `temp` (°C), `fan` (RPM), `in` (V), `curr` (A),
`power` (W).

### `ninfo battery`

Battery state from `/sys/class/power_supply` — laptops only; desktops
print `(no batteries)`. Health is full capacity as a fraction of
design capacity (a worn battery reads below 100%).

```
Battery
  BAT1
    State: Full
    Charge: 100.0%
    Level: Full
    Voltage: 12.86 V
    Energy: 38.2 / 38.2 Wh
    Health: 82.6%
```

## Options

| Option | Effect |
|--------|--------|
| `--json` | JSON output; deterministic key order, `null` for unavailable values |
| `--plain` | No ANSI colors, no layout decoration |
| `--no-color` | Disable ANSI colors only (layout unchanged) |
| `-h`, `--help` | Show help |
| `-v`, `--version` | Show version |

Options may appear before or after the command: `ninfo --json cpu` and
`ninfo cpu --json` are equivalent.

## JSON output

Every command accepts `--json`. Byte counts are plain integers; scripts
can format them. Unavailable values are `null`, never omitted keys.

```sh
ninfo cpu --json
```

```json
{
  "model": "AMD Ryzen 5 5600X 6-Core Processor",
  "physical_cores": 6,
  "logical_cores": 12,
  "mhz": 4650.0
}
```

`ninfo --json` (no command) returns one object with a key per section:

```json
{
  "system": { "os": "...", "kernel": "...", "architecture": "...",
              "hostname": "...", "uptime_seconds": 277932 },
  "cpu": { "model": "...", "physical_cores": 6, "logical_cores": 12,
           "mhz": 4650.0 },
  "memory": { "total_bytes": 33522163712, "used_bytes": 13324296192,
              "available_bytes": 20197867520, "used_percent": 39.7,
              "swap_total_bytes": 8589934592, "swap_used_bytes": 536870912 },
  "storage": [ { "device": "/dev/nvme0n1p2", "mount_point": "/",
                 "type": "ext4", "total_bytes": 1000204886016,
                 "used_bytes": 443093025792, "available_bytes": 506761857049,
                 "used_percent": 46.6 } ],
  "network": { "interfaces": [ { "name": "lo", "ipv4": "127.0.0.1",
                                 "ipv6": "::1", "mac": "00:00:00:00:00:00",
                                 "loopback": true, "up": true } ],
               "default_gateway": "10.0.0.1" },
  "processes": { "total": 214, "running": 3, "sleeping": 148, "zombie": 0 }
}
```

### Scripting examples

Total RAM in GiB:

```sh
ninfo memory --json | jq '.total_bytes / 1073741824'
```

Alert when root filesystem is over 90% full:

```sh
use=$(ninfo storage --json | jq -r '.[] | select(.mount_point == "/") | .used_percent')
awk -v u="$use" 'BEGIN { exit !(u > 90) }' && echo "root filesystem ${use}% full"
```

Hostname and uptime for a fleet report:

```sh
ninfo system --json | jq -r '[.hostname, .uptime_seconds] | @tsv'
```

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Runtime error — data could not be collected |
| 2 | Usage error — unknown command or option |

Errors print a single line to stderr, never a stack trace:

```
$ ninfo bogus
ninfo: unknown command 'bogus' (try 'ninfo --help')
Try 'ninfo --help' for usage.
$ echo $?
2
```

## Privileges

`ninfo` needs no root privileges. All data sources (`/proc`, `/sys`,
`/etc/os-release`, `getifaddrs`, `statvfs`) are readable by regular users.
It reads only these paths and never writes anything.
