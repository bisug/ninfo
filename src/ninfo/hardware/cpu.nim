## CPU information collector (Linux).
##
## Sources:
##   - /proc/cpuinfo  -> model name, core counts
##   - /sys/devices/system/cpu/cpu*/topology/{core_id,physical_package_id}
##   - /proc/cpuinfo "cpu MHz" or /sys .../cpufreq/cpuinfo_max_freq

import std/[os, strutils, options, sets, tables, posix]
import ../core/types

proc parseCpuinfo*(): tuple[fields: Table[string, string], logicalCores: Option[int]] =
  ## Parse /proc/cpuinfo in a single pass: key -> value table (last value
  ## wins) plus the logical core count (highest "processor" index + 1).
  ## Reading the file once keeps the two derived values consistent.
  ## Exported for unit tests.
  result = (initTable[string, string](), none(int))
  var maxProcessor = -1
  try:
    for line in readFile("/proc/cpuinfo").splitLines():
      let idx = line.find(':')
      if idx <= 0:
        continue
      let key = line[0 ..< idx].strip()
      let val = line[idx + 1 ..^ 1].strip()
      if key.len == 0:
        continue
      result.fields[key] = val
      if key == "processor":
        try:
          maxProcessor = max(maxProcessor, val.parseInt())
        except ValueError:
          discard
  except IOError, OSError:
    discard
  if maxProcessor >= 0:
    result.logicalCores = some(maxProcessor + 1)

proc countPhysicalCores*(): Option[int] =
  ## Count distinct (physical_package_id, core_id) pairs from sysfs.
  ## This is the accurate physical core count; /proc/cpuinfo's "cpu cores"
  ## only reports the per-socket count and is wrong on multi-socket systems.
  var packages = initHashSet[tuple[pkg, core: int]]()
  for kind, name in walkDir("/sys/devices/system/cpu"):
    # Only numeric cpuN directories carry topology.
    if kind != pcDir:
      continue
    let base = name.splitPath().tail
    if base.len == 0 or base[0] != 'c' or
       base.len < 4 or not base[3..^1].allCharsInSet(Digits):
      continue
    try:
      let pkg = readFile(name & "/topology/physical_package_id").strip().parseInt()
      let core = readFile(name & "/topology/core_id").strip().parseInt()
      packages.incl((pkg, core))
    except IOError, OSError, ValueError:
      discard
  if packages.len > 0:
    some(packages.len)
  else:
    none(int)

proc collectCpu*(): CpuInfo =
  var info: CpuInfo
  let (cpuinfo, logical) = parseCpuinfo()

  if "model name" in cpuinfo:
    info.modelName = some(cpuinfo["model name"])

  if logical.isSome:
    info.logicalCores = logical
  else:
    # Fall back to sysconf(_SC_NPROCESSORS_ONLN).
    let n = posix.sysconf(posix.SC_NPROCESSORS_ONLN)
    if n > 0:
      info.logicalCores = some(n)

  info.physicalCores = countPhysicalCores()

  # Frequency: prefer sysfs cpuinfo_max_freq (kHz), fall back to cpu MHz.
  try:
    let khz = readFile("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq")
      .strip().parseInt()
    info.mhz = some(khz.float / 1000.0)
  except IOError, OSError, ValueError:
    if "cpu MHz" in cpuinfo:
      try:
        info.mhz = some(cpuinfo["cpu MHz"].parseFloat())
      except ValueError:
        discard
  info
