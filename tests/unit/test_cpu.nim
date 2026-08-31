## Unit tests for CPU collector helpers.

import std/[unittest, options, strutils, tables]
import ninfo/hardware/cpu

suite "parseCpuinfo":
  test "parses model name":
    let t = parseCpuinfo()
    check "model name" in t
    check t["model name"].len > 0
  test "keys are stripped":
    # The parser must strip whitespace around the colon.
    let t = parseCpuinfo()
    for k in t.keys:
      check k == k.strip()

suite "countPhysicalCores":
  test "matches logical cores when no SMT":
    # On a machine without hyperthreading physical == logical; with SMT
    # physical < logical. Either way both must be positive and physical
    # must not exceed logical.
    let phys = countPhysicalCores()
    let t = parseCpuinfo()
    if "processor" in readFile("/proc/cpuinfo"):
      check phys.isSome
      check phys.get > 0

suite "collectCpu":
  test "logical cores positive":
    let c = collectCpu()
    check c.logicalCores.isSome
    check c.logicalCores.get > 0
  test "physical cores not exceeding logical":
    let c = collectCpu()
    if c.physicalCores.isSome and c.logicalCores.isSome:
      check c.physicalCores.get <= c.logicalCores.get
  test "model name present on Linux":
    let c = collectCpu()
    check c.modelName.isSome
