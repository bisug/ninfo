## Terminal/plain-text renderer.
##
## Pure presentation: takes already-collected data, produces a string.
## Never touches /proc or sysfs itself.

import std/[strutils, options, sets]
import ../core/types
import ../cli/options
import ../utils/format

type
  Palette = object
    ## ANSI color codes; empty strings when color is disabled.
    label: string    ## bold for field labels
    value: string     ## default for values
    accent: string    ## cyan for section headers
    reset: string

proc makePalette(noColor: bool): Palette =
  if noColor:
    Palette(label: "", value: "", accent: "", reset: "")
  else:
    Palette(label: "\e[1m", value: "", accent: "\e[36m", reset: "\e[0m")

proc row(p: Palette, label, value: string): string =
  p.label & label & p.reset & ": " & value

proc section(p: Palette, title: string): string =
  p.accent & title & p.reset

proc renderSystem(p: Palette, sys: SystemInfo): string =
  result = section(p, "System") & "\n"
  result.add row(p, "OS", sys.osName) & "\n"
  result.add row(p, "Kernel", sys.kernelVersion) & "\n"
  result.add row(p, "Architecture", sys.architecture) & "\n"
  result.add row(p, "Hostname", sys.hostname) & "\n"
  result.add row(p, "Uptime", humanUptime(sys.uptimeSeconds)) & "\n"

proc renderCpu(p: Palette, cpu: CpuInfo): string =
  result = section(p, "CPU") & "\n"
  result.add row(p, "Model", orNa(cpu.modelName)) & "\n"
  result.add row(p, "Physical cores", orNa(cpu.physicalCores)) & "\n"
  result.add row(p, "Logical cores", orNa(cpu.logicalCores)) & "\n"
  result.add row(p, "Frequency", orNa(cpu.mhz) & " MHz") & "\n"

proc renderMemory(p: Palette, mem: MemoryInfo): string =
  result = section(p, "Memory") & "\n"
  result.add row(p, "Total", orNa(mem.totalBytes)) & "\n"
  result.add row(p, "Used", orNa(mem.usedBytes)) & "\n"
  result.add row(p, "Available", orNa(mem.availableBytes)) & "\n"
  result.add row(p, "Usage", percentString(mem.usedPercent)) & "\n"
  if mem.swapTotalBytes.isSome:
    result.add row(p, "Swap total", orNa(mem.swapTotalBytes)) & "\n"
    result.add row(p, "Swap used", orNa(mem.swapUsedBytes)) & "\n"

proc renderStorage(p: Palette, fsList: seq[FilesystemInfo]): string =
  result = section(p, "Storage") & "\n"
  if fsList.len == 0:
    result.add "  (no filesystems)\n"
    return
  # Column layout, readable on narrow terminals.
  let header = align("Filesystem", 16) & align("Size", 10) &
               align("Used", 10) & align("Avail", 10) &
               align("Use%", 6) & "  Mounted on"
  result.add "  " & header & "\n"
  for fs in fsList:
    let usePct = if fs.usedPercent.isSome: $fs.usedPercent.get & "%" else: "n/a"
    result.add "  " & align(fs.device, 16) & align(orNa(fs.totalBytes), 10) &
      align(orNa(fs.usedBytes), 10) & align(orNa(fs.availableBytes), 10) &
      align(usePct, 6) & "  " & fs.mountPoint & "\n"

proc renderNetwork(p: Palette, net: NetworkInfo): string =
  result = section(p, "Network") & "\n"
  if net.interfaces.len == 0:
    result.add "  (no interfaces)\n"
  for iface in net.interfaces:
    var flags: seq[string] = @[]
    if iface.isUp: flags.add("up")
    if iface.isLoopback: flags.add("loopback")
    result.add "  " & section(p, iface.name) &
      (if flags.len > 0: " (" & flags.join(", ") & ")" else: "") & "\n"
    result.add "    " & row(p, "IPv4", orNa(iface.ipv4)) & "\n"
    result.add "    " & row(p, "IPv6", orNa(iface.ipv6)) & "\n"
    result.add "    " & row(p, "MAC", orNa(iface.macAddress)) & "\n"
  # Shown even when the interface list is empty: the gateway comes from
  # /proc/net/route, which can be readable when getifaddrs fails.
  result.add "  " & row(p, "Default gateway", orNa(net.defaultGateway)) & "\n"

proc renderProcesses(p: Palette, procs: ProcessInfo): string =
  result = section(p, "Processes") & "\n"
  result.add row(p, "Total", $procs.total) & "\n"
  result.add row(p, "Running", $procs.running) & "\n"
  result.add row(p, "Sleeping", $procs.sleeping) & "\n"
  result.add row(p, "Zombie", $procs.zombie) & "\n"

proc sensorUnit(kind: string): string =
  case kind
  of "temp": "°C"
  of "fan": "RPM"
  of "in": "V"
  of "curr": "A"
  of "power": "W"
  else: ""

proc formatSensorValue(v: Option[float], kind: string): string =
  ## One decimal for temps/currents, integers for fans, three for volts.
  if v.isNone:
    return "n/a"
  let unit = sensorUnit(kind)
  case kind
  of "temp", "curr":
    result = formatFloat(v.get, format = ffDecimal, precision = 1) & " " & unit
  of "fan":
    result = $int(v.get) & " " & unit
  of "in":
    result = formatFloat(v.get, format = ffDecimal, precision = 3) & " " & unit
  else:
    result = formatFloat(v.get, format = ffDecimal, precision = 2) & " " & unit

proc renderSensors(p: Palette, sensors: SensorsInfo): string =
  result = section(p, "Sensors") & "\n"
  if sensors.readings.len == 0:
    result.add "  (no sensors)\n"
    return
  # Group by chip, preserving first-seen order.
  var order: seq[string] = @[]
  var seen = initHashSet[string]()
  for r in sensors.readings:
    if r.chip notin seen:
      seen.incl(r.chip)
      order.add(r.chip)
  for chip in order:
    result.add "  " & section(p, chip) & "\n"
    for r in sensors.readings:
      if r.chip != chip:
        continue
      let name = r.label.get($r.kind & " " & $r.number)
      var line = "    " & row(p, name, formatSensorValue(r.value, r.kind))
      if r.critical.isSome:
        line.add " (crit " & formatSensorValue(r.critical, r.kind) & ")"
      result.add line & "\n"

proc renderBattery(p: Palette, bats: BatteriesInfo): string =
  result = section(p, "Battery") & "\n"
  if bats.batteries.len == 0:
    result.add "  (no batteries)\n"
    return
  for b in bats.batteries:
    result.add "  " & section(p, b.name) & "\n"
    result.add "    " & row(p, "State", orNa(b.state)) & "\n"
    if b.capacityPercent.isSome:
      result.add "    " & row(p, "Charge",
        formatFloat(b.capacityPercent.get, ffDecimal, 1) & "%") & "\n"
    else:
      result.add "    " & row(p, "Charge", "n/a") & "\n"
    if b.capacityLevel.isSome:
      result.add "    " & row(p, "Level", b.capacityLevel.get) & "\n"
    if b.voltageVolts.isSome:
      result.add "    " & row(p, "Voltage",
        formatFloat(b.voltageVolts.get, ffDecimal, 2) & " V") & "\n"
    if b.energyNowWh.isSome and b.energyFullWh.isSome:
      result.add "    " & row(p, "Energy",
        formatFloat(b.energyNowWh.get, ffDecimal, 1) & " / " &
        formatFloat(b.energyFullWh.get, ffDecimal, 1) & " Wh") & "\n"
    if b.energyDesignWh.isSome and b.energyFullWh.isSome and
       b.energyDesignWh.get > 0:
      # Health: full capacity as a fraction of design capacity.
      let health = b.energyFullWh.get / b.energyDesignWh.get * 100.0
      result.add "    " & row(p, "Health",
        formatFloat(health, ffDecimal, 1) & "%") & "\n"
    if b.hoursToEmpty.isSome:
      result.add "    " & row(p, "Time to empty",
        humanUptime(int(b.hoursToEmpty.get * 3600))) & "\n"
    if b.hoursToFull.isSome:
      result.add "    " & row(p, "Time to full",
        humanUptime(int(b.hoursToFull.get * 3600))) & "\n"

proc renderText*(sys: SystemInfo, cpu: CpuInfo, mem: MemoryInfo,
                 fsList: seq[FilesystemInfo], net: NetworkInfo,
                 procs: ProcessInfo, sensors: SensorsInfo,
                 batteries: BatteriesInfo, command: Command,
                 noColor: bool): string =
  ## Render the requested command's view. For cmdAll, every section is
  ## included; for specific commands only the relevant section appears.
  let p = makePalette(noColor)
  var parts: seq[string] = @[]
  case command
  of cmdAll:
    parts.add(renderSystem(p, sys))
    parts.add(renderCpu(p, cpu))
    parts.add(renderMemory(p, mem))
    parts.add(renderStorage(p, fsList))
    parts.add(renderNetwork(p, net))
    parts.add(renderProcesses(p, procs))
    parts.add(renderSensors(p, sensors))
    parts.add(renderBattery(p, batteries))
  of cmdSystem: parts.add(renderSystem(p, sys))
  of cmdCpu: parts.add(renderCpu(p, cpu))
  of cmdMemory: parts.add(renderMemory(p, mem))
  of cmdStorage: parts.add(renderStorage(p, fsList))
  of cmdNetwork: parts.add(renderNetwork(p, net))
  of cmdProcesses: parts.add(renderProcesses(p, procs))
  of cmdSensors: parts.add(renderSensors(p, sensors))
  of cmdBattery: parts.add(renderBattery(p, batteries))
  else: discard
  parts.join("\n").strip(leading = false)
