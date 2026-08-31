## Unit tests for CPU collector helpers.

import std/[unittest, options, strutils, tables]
import ninfo/hardware/cpu

suite "parseCpuinfo":
  test "parses model name":
    let (t, _) = parseCpuinfo()
    check "model name" in t
    check t["model name"].len > 0
  test "keys are stripped":
    # The parser must strip whitespace around the colon.
    let (t, _) = parseCpuinfo()
    for k in t.keys:
      check k == k.strip()
  test "logical cores from processor lines":
    let (_, logical) = parseCpuinfo()
    check logical.isSome
    check logical.get > 0

suite "countPhysicalCores":
  test "positive when cpuinfo has processors":
    let phys = countPhysicalCores()
    let (_, logical) = parseCpuinfo()
    if logical.isSome:
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
