# Architecture

## Design principles

1. **Collectors and renderers are strictly separated.** A collector's only
   job is to produce a typed domain object; a renderer's only job is to turn
   that object into text or JSON. Renderers never read `/proc` or `/sys`,
   which keeps them unit-testable with plain object literals.
2. **Unavailable data is explicit.** Fields that may be missing on some
   systems are `Option[T]`. Renderers print `n/a` for `None`; the JSON
   renderer emits `null`. Nothing is guessed or defaulted to zero.
3. **Native interfaces only.** No shelling out to `ip`, `lscpu`, `free`,
   `df` or `uname`. Everything comes from `/proc`, `/sys` or direct libc
   calls. This makes `ninfo` fast, dependency-free and safe to run in
   restricted environments.
4. **No root, no globals.** All sources are world-readable. There is no
   global mutable state; every collector is a pure function from the
   filesystem to a value.
5. **Fail gracefully.** A missing file degrades that field to `None`; it
   never crashes the whole command. Only a total failure to collect
   anything surfaces as an error (exit code 1).

## Module map

```
src/ninfo.nim            thin entry: parse -> dispatch -> quit(code)
src/ninfo/cli/options.nim   argument parsing (std/parseopt), usage text
src/ninfo/cli/main.nim      command dispatch, exit codes, error handling
src/ninfo/core/types.nim    domain objects shared by collectors/renderers
src/ninfo/system/collector.nim   OS, kernel, arch, hostname, uptime
src/ninfo/hardware/cpu.nim       CPU model, cores, frequency
src/ninfo/hardware/memory.nim    RAM and swap statistics
src/ninfo/storage/filesystems.nim  mount enumeration + statvfs
src/ninfo/network/interfaces.nim   getifaddrs + /proc/net/route + sysfs MACs
src/ninfo/process/stats.nim        /proc scan and state classification
src/ninfo/output/text.nim       terminal/plain renderer
src/ninfo/output/jsonout.nim   deterministic JSON renderer
src/ninfo/utils/format.nim     byte/uptime/percentage formatting
```

## Data flow

```
argv ──> parseCliOptions ──> Command + flags
                                   │
                    ┌──────────────┴──────────────┐
                    │ collect only what the        │
                    │ chosen command needs         │
                    └──────────────┬──────────────┘
                                   │
              SystemInfo / CpuInfo / ... (typed objects)
                                   │
                    ┌──────────────┴──────────────┐
                    │ renderText or renderJson    │
                    └──────────────┬──────────────┘
                                   │
                               stdout
```

`ninfo cpu` never touches the memory or network code paths, so a bug in one
collector cannot affect another command.

## Data sources

| Data | Source | Notes |
|------|--------|-------|
| OS name | `/etc/os-release` (`PRETTY_NAME`) | falls back to `/usr/lib/os-release`, then "Linux" |
| Kernel, arch | `uname(2)` | via `std/posix`; char arrays are NUL-trimmed |
| Hostname | `/proc/sys/kernel/hostname` | falls back to `gethostname(2)` |
| Uptime | `/proc/uptime` first field | integer seconds |
| CPU model | `/proc/cpuinfo` `model name` | |
| Physical cores | `/sys/devices/system/cpu/cpuN/topology/` | distinct `(package, core)` pairs; more accurate than `cpu cores` on multi-socket systems |
| Logical cores | `/proc/cpuinfo` `processor` max | falls back to `sysconf(_SC_NPROCESSORS_ONLN)` |
| CPU frequency | `/sys/.../cpuinfo_max_freq` (kHz) | falls back to `cpu MHz` |
| Memory | `/proc/meminfo` | used = total − available (modern kernels); legacy fallback: total − free − buffers − cached |
| Swap | `/proc/meminfo` `SwapTotal`/`SwapFree` | omitted entirely when swap is 0 |
| Filesystems | `/proc/self/mountinfo` + `statvfs(2)` | pseudo filesystems (proc, sysfs, tmpfs, ...) are filtered out |
| Interfaces | `getifaddrs(3)` | bound directly from glibc — Nim's `std/posix` does not wrap it |
| MAC addresses | `/sys/class/net/<if>/address` | `getifaddrs` does not expose link-layer addresses portably |
| Default gateway | `/proc/net/route` | destination `00000000`; gateway is little-endian hex IPv4 |
| Processes | `/proc/<pid>/stat` | state char after the last `)` in the line (comm may contain spaces and parens) |

## Non-obvious behaviors

- **mountinfo octal escapes.** Mount points with spaces appear in
  `/proc/self/mountinfo` as `\040`. `unescapePath` decodes these before
  `statvfs` is called, or spaces in mount points would break capacity
  lookups.
- **statvfs used vs. available.** "Used" is computed from `f_bfree` (blocks
  available to root), not `f_bavail` (blocks available to unprivileged
  users), matching `df`'s convention. The "Avail" column shows `f_bavail`.
- **Process state parsing.** `/proc/<pid>/stat` field 2 (`comm`) can contain
  spaces and parentheses (e.g. `((sd-pam))`). The state character is taken
  after the *last* `)` in the line, not by whitespace splitting.
- **getifaddrs binding.** The `Ifaddrs` object is declared with
  `importc`/`header: "<ifaddrs.h>"` so the C compiler lays it out; the
  struct is walked via `ifa_next` and freed with `freeifaddrs`.
- **Utsname conversion.** `uname` fills fixed char arrays with trailing
  NULs; `$uts.machine` would render a char list, so fields pass through
  `cCharArrayToString` which stops at the first NUL.

## Error handling

- `parseCliOptions` raises `CliError` for bad commands/options → exit 2
  with a one-line message, no stack trace.
- Collectors return `Option.none` fields for missing data; they only raise
  if even a partial result is impossible → exit 1.
- `main` catches `CatchableError` at the top level so no user-facing path
  can produce a stack trace.

## Testing strategy

- **Unit tests** target pure logic: meminfo table → `MemoryInfo`, mountinfo
  parsing, octal unescaping, state classification, byte/uptime formatting,
  CLI parsing, JSON shape. These run anywhere without a specific machine.
- **Integration tests** run the real binary and assert on output shape,
  exit codes and JSON validity — not on machine-specific values.
- Machine-dependent assertions are deliberately weak (e.g. "physical cores
  ≤ logical cores") so the suite passes on any Linux host.
