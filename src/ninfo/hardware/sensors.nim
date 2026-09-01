## Hardware sensor collector (Linux).
##
## Walks /sys/class/hwmon — the same data `sensors` reads — with no
## external commands. Each hwmon chip directory exposes sensor files
## named <kind><number>_<property>:
##
##   temp1_input  63000   millidegrees Celsius
##   temp1_label  "Package id 0"   (optional)
##   temp1_max    105000  millidegrees (optional)
##   temp1_crit   105000  millidegrees (optional)
##   fan1_input   RPM     (milli-RPM per the ABI, but no driver uses it)
##   in0_input    millivolts
##   curr1_input  milliamps
##   power1_input microwatts
##
## Kinds we surface: temp, fan, in, curr, power. Values are scaled to
## human units (deg C, RPM, volts, amps, watts). Files that vanish
## between the directory listing and the read (hotplug) are skipped,
## not fatal.

import std/[os, strutils, options, algorithm]
import ../core/types

const sensorKinds = ["temp", "fan", "in", "curr", "power"]

proc readMilli*(path: string): Option[float] =
  ## Read a sysfs file holding an integer in milli/micro units and
  ## scale it to the base unit. None when unreadable or non-numeric.
  try:
    let raw = readFile(path).strip()
    if raw.len == 0:
      return none(float)
    let v = raw.parseInt()
    # The hwmon ABI uses milli-units for temp/fan/in/curr and micro for
    # power; callers pass the divisor.
    some(v.float)
  except IOError, OSError, ValueError:
    none(float)

proc sensorFilesForKind*(dir, kind: string): seq[int] =
  ## Sensor numbers present for a kind, sorted ascending.
  ## A chip with temp1..temp4 yields @[1, 2, 3, 4] for kind "temp".
  result = @[]
  for f in walkFiles(dir & "/" & kind & "*_input"):
    let base = f.splitFile().name
    # base is like "temp3_input"; strip the kind prefix and _input suffix.
    let numPart = base[kind.len ..< base.len - "_input".len]
    if numPart.len > 0 and numPart.allCharsInSet(Digits):
      result.add(numPart.parseInt())
  result.sort()

proc collectSensors*(): SensorsInfo =
  ## Gather every sensor reading from every hwmon chip.
  ## Returns an empty SensorsInfo when hwmon is absent (containers,
  ## some VMs) — sensors are optional hardware, not an error.
  result = SensorsInfo(readings: @[])
  const hwmonRoot = "/sys/class/hwmon"
  if not dirExists(hwmonRoot):
    return

  # /sys/class/hwmon entries are symlinks into /sys/devices; accept both
  # pcDir (real dir) and pcLinkToDir (sysfs symlink) so the walk works
  # on either layout.
  for kind, dir in walkDir(hwmonRoot):
    if kind != pcDir and kind != pcLinkToDir:
      continue
    let chipName =
      try:
        readFile(dir & "/name").strip()
      except IOError, OSError:
        ""  # Chip without a name file: still usable, label it by path.
    if chipName.len == 0:
      continue

    for sensorKind in sensorKinds:
      for num in sensorFilesForKind(dir, sensorKind):
        var r: SensorReading
        r.chip = chipName
        r.kind = sensorKind
        r.number = num

        # Optional label file.
        try:
          let lbl = readFile(dir & "/" & sensorKind & $num & "_label").strip()
          if lbl.len > 0:
            r.label = some(lbl)
        except IOError, OSError:
          discard

        # Value: scale milli/micro units to base units.
        let inputPath = dir & "/" & sensorKind & $num & "_input"
        let raw = readMilli(inputPath)
        if raw.isNone:
          continue  # Sensor present but no live value; skip it.
        let divisor =
          if sensorKind == "power": 1_000_000.0
          else: 1_000.0
        r.value = some(raw.get / divisor)

        # Optional thresholds, same scaling.
        let maxT = readMilli(dir & "/" & sensorKind & $num & "_max")
        if maxT.isSome:
          r.max = some(maxT.get / divisor)
        let critT = readMilli(dir & "/" & sensorKind & $num & "_crit")
        if critT.isSome:
          r.critical = some(critT.get / divisor)

        result.readings.add(r)
