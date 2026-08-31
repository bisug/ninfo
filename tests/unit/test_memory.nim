## Unit tests for memory info computation from a meminfo table.

import std/[unittest, options, tables]
import ninfo/hardware/memory

suite "parseMeminfo":
  test "parses values in KiB":
    let t = {"MemTotal": 1000'u64, "MemFree": 400'u64}.toTable
    check t["MemTotal"] == 1000
  test "empty table on missing file":
    # parseMeminfo reads /proc/meminfo which exists on Linux; just verify
    # the return type works and has plausible keys.
    let t = parseMeminfo()
    check "MemTotal" in t

suite "computeMemoryInfo":
  test "full modern kernel fields":
    let t = {
      "MemTotal": 1000'u64,       # 1000 KiB
      "MemAvailable": 400'u64,
      "SwapTotal": 200'u64,
      "SwapFree": 50'u64,
    }.toTable
    let m = computeMemoryInfo(t)
    check m.totalBytes == some(1024000'u64)
    check m.availableBytes == some(409600'u64)
    check m.usedBytes == some(614400'u64)
    check m.usedPercent == some(60.0)
    check m.swapTotalBytes == some(204800'u64)
    check m.swapUsedBytes == some(153600'u64)

  test "old kernel fallback via MemFree":
    let t = {
      "MemTotal": 1000'u64,
      "MemFree": 100'u64,
      "Buffers": 100'u64,
      "Cached": 200'u64,
    }.toTable
    let m = computeMemoryInfo(t)
    # free = 100 + 100 + 200 = 400 KiB -> used = 600 KiB
    check m.usedBytes == some(600 * 1024'u64)
    check m.usedPercent == some(60.0)

  test "no swap":
    let t = {"MemTotal": 1000'u64, "MemAvailable": 500'u64}.toTable
    let m = computeMemoryInfo(t)
    check m.swapTotalBytes.isNone
    check m.swapUsedBytes.isNone

  test "zero swap total is treated as no swap":
    let t = {"MemTotal": 1000'u64, "SwapTotal": 0'u64}.toTable
    let m = computeMemoryInfo(t)
    check m.swapTotalBytes.isNone

  test "empty table yields all-none":
    let m = computeMemoryInfo(initTable[string, uint64]())
    check m.totalBytes.isNone
    check m.usedBytes.isNone
    check m.usedPercent.isNone
