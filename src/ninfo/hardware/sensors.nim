## Hardware sensor collector: walks /sys/class/hwmon (the source
## `sensors` reads). File naming: <kind><num>_<property>.
## Units per the hwmon ABI: temp/fan/in/curr are milli-, power is micro-.

import std/[os, strutils, options, algorithm]
import ../core/types

const sensorKinds = ["temp", "fan", "in", "curr", "power"]

proc readMilli*(path: string): Option[float] =
  ## Raw integer from a sysfs file; None when unreadable or non-numeric.
  try:
    let raw = readFile(path).strip()
    if raw.len == 0:
      return none(float)
    some(raw.parseInt().float)
  except IOError, OSError, ValueError:
    none(float)

proc sensorFilesForKind*(dir, kind: string): seq[int] =
  ## Sensor numbers present for a kind, sorted ascending.
  result = @[]
  for f in walkFiles(dir & "/" & kind & "*_input"):
    let base = f.splitFile().name
    let numPart = base[kind.len ..< base.len - "_input".len]
    if numPart.len > 0 and numPart.allCharsInSet(Digits):
      result.add(numPart.parseInt())
  result.sort()

proc collectSensors*(): SensorsInfo =
  ## Empty when hwmon is absent (containers, some VMs) — optional
  ## hardware, not an error.
  result = SensorsInfo(readings: @[])
  const hwmonRoot = "/sys/class/hwmon"
  if not dirExists(hwmonRoot):
    return

  # sysfs class entries are symlinks, so walkDir yields pcLinkToDir.
  for kind, dir in walkDir(hwmonRoot):
    if kind != pcDir and kind != pcLinkToDir:
      continue
    let chipName =
      try:
        readFile(dir & "/name").strip()
      except IOError, OSError:
        ""
    if chipName.len == 0:
      continue

    for sensorKind in sensorKinds:
      for num in sensorFilesForKind(dir, sensorKind):
        var r: SensorReading
        r.chip = chipName
        r.kind = sensorKind
        r.number = num

        try:
          let lbl = readFile(dir & "/" & sensorKind & $num & "_label").strip()
          if lbl.len > 0:
            r.label = some(lbl)
        except IOError, OSError:
          discard

        let raw = readMilli(dir & "/" & sensorKind & $num & "_input")
        if raw.isNone:
          continue  # no live value
        let divisor =
          if sensorKind == "power": 1_000_000.0
          else: 1_000.0
        r.value = some(raw.get / divisor)

        let maxT = readMilli(dir & "/" & sensorKind & $num & "_max")
        if maxT.isSome:
          r.max = some(maxT.get / divisor)
        let critT = readMilli(dir & "/" & sensorKind & $num & "_crit")
        if critT.isSome:
          r.critical = some(critT.get / divisor)

        result.readings.add(r)
