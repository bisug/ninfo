## Terminal/plain-text renderer.
##
## Pure presentation: takes already-collected data, produces a string.
## Never touches /proc or sysfs itself.

import std/[strutils, options]
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
    return
  for iface in net.interfaces:
    var flags: seq[string] = @[]
    if iface.isUp: flags.add("up")
    if iface.isLoopback: flags.add("loopback")
    result.add "  " & section(p, iface.name) &
      (if flags.len > 0: " (" & flags.join(", ") & ")" else: "") & "\n"
    result.add "    " & row(p, "IPv4", orNa(iface.ipv4)) & "\n"
    result.add "    " & row(p, "IPv6", orNa(iface.ipv6)) & "\n"
    result.add "    " & row(p, "MAC", orNa(iface.macAddress)) & "\n"
  result.add "  " & row(p, "Default gateway", orNa(net.defaultGateway)) & "\n"

proc renderProcesses(p: Palette, procs: ProcessInfo): string =
  result = section(p, "Processes") & "\n"
  result.add row(p, "Total", $procs.total) & "\n"
  result.add row(p, "Running", $procs.running) & "\n"
  result.add row(p, "Sleeping", $procs.sleeping) & "\n"
  result.add row(p, "Zombie", $procs.zombie) & "\n"

proc renderText*(sys: SystemInfo, cpu: CpuInfo, mem: MemoryInfo,
                 fsList: seq[FilesystemInfo], net: NetworkInfo,
                 procs: ProcessInfo, command: Command,
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
  of cmdSystem: parts.add(renderSystem(p, sys))
  of cmdCpu: parts.add(renderCpu(p, cpu))
  of cmdMemory: parts.add(renderMemory(p, mem))
  of cmdStorage: parts.add(renderStorage(p, fsList))
  of cmdNetwork: parts.add(renderNetwork(p, net))
  of cmdProcesses: parts.add(renderProcesses(p, procs))
  else: discard
  parts.join("\n").strip(leading = false)
