## Entry point: dispatch parsed CLI options to collectors and renderers.

import std/os
import ../core/types
import ../cli/options
import ../system/collector
import ../hardware/cpu
import ../hardware/memory
import ../hardware/sensors
import ../hardware/battery
import ../storage/filesystems
import ../network/interfaces
import ../process/stats
import ../output/text
import ../output/jsonout

const exitOk = 0
const exitRuntime = 1
const exitUsage = 2

proc render(opts: CliOptions, sys: SystemInfo, cpu: CpuInfo, mem: MemoryInfo,
            fs: seq[FilesystemInfo], net: NetworkInfo, procs: ProcessInfo,
            sensors: SensorsInfo, batteries: BatteriesInfo): string =
  if opts.json:
    renderJson(sys, cpu, mem, fs, net, procs, sensors, batteries, opts.command)
  else:
    renderText(sys, cpu, mem, fs, net, procs, sensors, batteries,
               opts.command, opts.noColor)

proc collectAndRender(opts: CliOptions): string =
  ## Collect only what the chosen command needs, then render.
  case opts.command
  of cmdSystem:
    render(opts, collectSystem(), default(CpuInfo), default(MemoryInfo),
           @[], default(NetworkInfo), default(ProcessInfo),
           default(SensorsInfo), default(BatteriesInfo))
  of cmdCpu:
    render(opts, default(SystemInfo), collectCpu(), default(MemoryInfo),
           @[], default(NetworkInfo), default(ProcessInfo),
           default(SensorsInfo), default(BatteriesInfo))
  of cmdMemory:
    render(opts, default(SystemInfo), default(CpuInfo), collectMemory(),
           @[], default(NetworkInfo), default(ProcessInfo),
           default(SensorsInfo), default(BatteriesInfo))
  of cmdStorage:
    render(opts, default(SystemInfo), default(CpuInfo), default(MemoryInfo),
           collectFilesystems(), default(NetworkInfo), default(ProcessInfo),
           default(SensorsInfo), default(BatteriesInfo))
  of cmdNetwork:
    render(opts, default(SystemInfo), default(CpuInfo), default(MemoryInfo),
           @[], collectNetwork(), default(ProcessInfo),
           default(SensorsInfo), default(BatteriesInfo))
  of cmdProcesses:
    render(opts, default(SystemInfo), default(CpuInfo), default(MemoryInfo),
           @[], default(NetworkInfo), collectProcesses(),
           default(SensorsInfo), default(BatteriesInfo))
  of cmdSensors:
    render(opts, default(SystemInfo), default(CpuInfo), default(MemoryInfo),
           @[], default(NetworkInfo), default(ProcessInfo), collectSensors(),
           default(BatteriesInfo))
  of cmdBattery:
    render(opts, default(SystemInfo), default(CpuInfo), default(MemoryInfo),
           @[], default(NetworkInfo), default(ProcessInfo),
           default(SensorsInfo), collectBatteries())
  else:
    render(opts, collectSystem(), collectCpu(), collectMemory(),
           collectFilesystems(), collectNetwork(), collectProcesses(),
           collectSensors(), collectBatteries())

proc ninfoMain*(args: seq[string] = commandLineParams()): int =
  ## Main entry. Returns the process exit code.
  try:
    let opts = parseCliOptions(args)
    case opts.command
    of cmdHelp:
      stdout.writeLine(usageText())
      return exitOk
    of cmdVersion:
      stdout.writeLine(progName & " " & versionString)
      return exitOk
    else:
      stdout.writeLine(collectAndRender(opts))
      return exitOk
  except CliError as e:
    stderr.writeLine("ninfo: " & e.msg)
    stderr.writeLine("Try 'ninfo --help' for usage.")
    return exitUsage
  except CatchableError as e:
    # Collectors degrade missing data to Option.none; reaching here means
    # a collection path failed outright. Exit cleanly without a trace.
    stderr.writeLine("ninfo: " & e.msg)
    return exitRuntime
