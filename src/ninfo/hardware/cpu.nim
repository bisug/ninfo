## CPU information collector (Linux).
##
## Sources:
##   - /proc/cpuinfo  -> model name, core counts
##   - /sys/devices/system/cpu/cpu*/topology/{core_id,physical_package_id}
##   - /proc/cpuinfo "cpu MHz" or /sys .../cpufreq/cpuinfo_max_freq

import std/[os, strutils, options, sets, tables, posix]
import ../core/types

proc parseCpuinfo*(): Table[string, string] =
  ## Parse /proc/cpuinfo into a key -> value table (last value wins).
  ## Exported for unit tests.
  result = initTable[string, string]()
  try:
    for line in readFile("/proc/cpuinfo").splitLines():
      let idx = line.find(':')
      if idx > 0:
        let key = line[0 ..< idx].strip()
        let val = line[idx + 1 ..^ 1].strip()
        if key.len > 0:
          result[key] = val
  except IOError, OSError:
    discard

proc countPhysicalCores*(): Option[int] =
  ## Count distinct (physical_package_id, core_id) pairs from sysfs.
  ## This is the accurate physical core count; /proc/cpuinfo's "cpu cores"
  ## only reports the per-socket count and is wrong on multi-socket systems.
  var packages = initHashSet[tuple[pkg, core: int]]()
  var cpu = 0
  while true:
    let dir = "/sys/devices/system/cpu/cpu" & $cpu
    if not dirExists(dir):
      break
    let pkgPath = dir & "/topology/physical_package_id"
    let corePath = dir & "/topology/core_id"
    try:
      let pkg = readFile(pkgPath).strip().parseInt()
      let core = readFile(corePath).strip().parseInt()
      packages.incl((pkg, core))
    except IOError, OSError, ValueError:
      discard
    inc cpu
  if packages.len > 0:
    some(packages.len)
  else:
    none(int)

proc collectCpu*(): CpuInfo =
  var info: CpuInfo
  let cpuinfo = parseCpuinfo()

  if "model name" in cpuinfo:
    info.modelName = some(cpuinfo["model name"])

  # Logical cores: highest processor N seen in /proc/cpuinfo + 1.
  # Fall back to sysfs cpu directory count, then sysconf(_SC_NPROCESSORS_ONLN).
  var maxProcessor = -1
  try:
    for line in readFile("/proc/cpuinfo").splitLines():
      if line.startsWith("processor"):
        let idx = line.find(':')
        if idx > 0:
          try:
            maxProcessor = max(maxProcessor,
                               line[idx + 1 ..^ 1].strip().parseInt())
          except ValueError:
            discard
  except IOError, OSError:
    discard
  if maxProcessor >= 0:
    info.logicalCores = some(maxProcessor + 1)
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
