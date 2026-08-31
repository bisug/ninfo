## Memory statistics collector (Linux).
##
## Reads /proc/meminfo - the same source the `free` command uses, but
## parsed directly. Values in meminfo are in KiB.

import std/[strutils, options, math, tables]
import ../core/types

proc parseMeminfo*(): Table[string, uint64] =
  ## Parse /proc/meminfo into a key -> KiB-value table.
  ## Exported for unit tests.
  result = initTable[string, uint64]()
  try:
    for line in readFile("/proc/meminfo").splitLines():
      let idx = line.find(':')
      if idx <= 0:
        continue
      let key = line[0 ..< idx]
      let rest = line[idx + 1 ..^ 1].strip()
      # Value is "<number> kB" - take the number.
      let num = rest.split(' ')[0]
      try:
        result[key] = num.parseBiggestUInt().uint64
      except ValueError:
        discard
  except IOError, OSError:
    discard

proc computeMemoryInfo*(meminfo: Table[string, uint64]): MemoryInfo =
  ## Build a MemoryInfo from a parsed meminfo table (KiB values).
  ## Exported for unit tests.
  var info: MemoryInfo

  if "MemTotal" in meminfo:
    info.totalBytes = some(meminfo["MemTotal"] * 1024'u64)
  if "MemAvailable" in meminfo:
    info.availableBytes = some(meminfo["MemAvailable"] * 1024'u64)

  # Used = total - available (matches `free`'s "used" semantics on modern
  # kernels; older kernels without MemAvailable fall back to
  # total - free - buffers - cached).
  if info.totalBytes.isSome:
    let total = info.totalBytes.get
    var used: uint64 = 0
    if info.availableBytes.isSome:
      let avail = min(total, info.availableBytes.get)
      used = total - avail
    elif "MemFree" in meminfo:
      var freeBytes = meminfo["MemFree"] * 1024'u64
      if "Buffers" in meminfo: freeBytes += meminfo["Buffers"] * 1024'u64
      if "Cached" in meminfo: freeBytes += meminfo["Cached"] * 1024'u64
      used = total - min(total, freeBytes)
    info.usedBytes = some(used)
    if used <= total and total > 0:
      info.usedPercent = some(round(used.float / total.float * 100.0, 1))

  if "SwapTotal" in meminfo and meminfo["SwapTotal"] > 0:
    info.swapTotalBytes = some(meminfo["SwapTotal"] * 1024'u64)
    if "SwapFree" in meminfo:
      let swapUsed = meminfo["SwapTotal"] - min(meminfo["SwapTotal"], meminfo["SwapFree"])
      info.swapUsedBytes = some(swapUsed * 1024'u64)
  info

proc collectMemory*(): MemoryInfo =
  computeMemoryInfo(parseMeminfo())
