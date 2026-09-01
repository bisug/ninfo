## Battery collector: walks /sys/class/power_supply, type=Battery only.
## Units per the power_supply ABI: energy µWh, charge µAh, voltage µV,
## current µA. time_to_*_now is minutes.

import std/[os, strutils, options]
import ../core/types

proc readSysInt*(path: string): Option[int] =
  try:
    some(readFile(path).strip().parseInt())
  except IOError, OSError, ValueError:
    none(int)

proc readSysStr*(path: string): Option[string] =
  try:
    let s = readFile(path).strip()
    if s.len > 0: some(s) else: none(string)
  except IOError, OSError:
    none(string)

proc collectBatteries*(): BatteriesInfo =
  ## All batteries; empty on desktops — not an error.
  result = BatteriesInfo(batteries: @[])
  const root = "/sys/class/power_supply"
  if not dirExists(root):
    return

  # sysfs class entries are symlinks, so walkDir yields pcLinkToDir.
  for kind, dir in walkDir(root):
    if kind != pcDir and kind != pcLinkToDir:
      continue
    if readSysStr(dir & "/type").get("") != "Battery":
      continue

    var b: BatteryInfo
    b.name = dir.splitPath().tail
    b.isPresent = readSysInt(dir & "/present").get(0) == 1
    b.state = readSysStr(dir & "/status")
    b.capacityLevel = readSysStr(dir & "/capacity_level")

    let cap = readSysInt(dir & "/capacity")
    if cap.isSome:
      b.capacityPercent = some(cap.get.float)

    let volts = readSysInt(dir & "/voltage_now")
    if volts.isSome and volts.get > 0:
      b.voltageVolts = some(volts.get.float / 1_000_000.0)

    # Energy-based (µWh) or charge-based (µAh); report both as Wh.
    let eNow = readSysInt(dir & "/energy_now")
    let eFull = readSysInt(dir & "/energy_full")
    let eDesign = readSysInt(dir & "/energy_full_design")
    let cNow = readSysInt(dir & "/charge_now")
    let cFull = readSysInt(dir & "/charge_full")
    let cDesign = readSysInt(dir & "/charge_full_design")
    if eNow.isSome:
      b.energyNowWh = some(eNow.get.float / 1_000_000.0)
    elif cNow.isSome and b.voltageVolts.isSome:
      # µAh × V = µWh.
      b.energyNowWh = some(cNow.get.float * b.voltageVolts.get / 1_000_000.0)
    if eFull.isSome:
      b.energyFullWh = some(eFull.get.float / 1_000_000.0)
    elif cFull.isSome and b.voltageVolts.isSome:
      b.energyFullWh = some(cFull.get.float * b.voltageVolts.get / 1_000_000.0)
    if eDesign.isSome:
      b.energyDesignWh = some(eDesign.get.float / 1_000_000.0)
    elif cDesign.isSome and b.voltageVolts.isSome:
      b.energyDesignWh = some(cDesign.get.float * b.voltageVolts.get / 1_000_000.0)

    b.cycleCount = readSysInt(dir & "/cycle_count")

    # Kernel-reported minutes; None when not applicable.
    let tEmpty = readSysInt(dir & "/time_to_empty_now")
    if tEmpty.isSome and tEmpty.get > 0:
      b.hoursToEmpty = some(tEmpty.get.float / 60.0)
    let tFull = readSysInt(dir & "/time_to_full_now")
    if tFull.isSome and tFull.get > 0:
      b.hoursToFull = some(tFull.get.float / 60.0)

    result.batteries.add(b)
