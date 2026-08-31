## Command-line parsing and global options.
##
## Uses std/parseopt. Commands are plain arguments; global flags may appear
## anywhere. Unknown options/commands produce a clean usage error (exit 2),
## never a stack trace.

import std/[parseopt, strutils, tables]

const
  versionString* = "0.1.0"
  progName* = "ninfo"

type
  Command* = enum
    cmdAll = "all"          ## `ninfo` with no command: show everything
    cmdSystem = "system"
    cmdCpu = "cpu"
    cmdMemory = "memory"
    cmdStorage = "storage"
    cmdNetwork = "network"
    cmdProcesses = "processes"
    cmdHelp = "help"
    cmdVersion = "version"

  CliOptions* = object
    command*: Command
    json*: bool              ## --json: machine-readable output
    plain*: bool             ## --plain: no colors, no fancy layout
    noColor*: bool           ## --no-color: disable ANSI colors only

  CliError* = object of CatchableError

const commandNames*: Table[string, Command] = {
  "system": cmdSystem,
  "cpu": cmdCpu,
  "memory": cmdMemory,
  "storage": cmdStorage,
  "network": cmdNetwork,
  "processes": cmdProcesses,
  "help": cmdHelp,
  "version": cmdVersion,
}.toTable

proc parseCliOptions*(args: seq[string]): CliOptions =
  ## Parse command-line arguments. Raises CliError on invalid input.
  runnableExamples:
    doAssert parseCliOptions(@["cpu", "--json"]).command == cmdCpu
    doAssert parseCliOptions(@["--json", "memory"]).json
  var opts = CliOptions(command: cmdAll)
  var sawCommand = false
  var p = initOptParser(args)
  for kind, key, val in p.getopt():
    case kind
    of cmdArgument:
      if sawCommand:
        raise newException(CliError,
          "unexpected argument '$1' (only one command allowed)" % [key])
      if key notin commandNames:
        raise newException(CliError,
          "unknown command '$1' (try 'ninfo --help')" % [key])
      opts.command = commandNames[key]
      sawCommand = true
    of cmdLongOption, cmdShortOption:
      case key
      of "help", "h": opts.command = cmdHelp
      of "version", "v": opts.command = cmdVersion
      of "json": opts.json = true
      of "plain": opts.plain = true
      of "no-color": opts.noColor = true
      else:
        raise newException(CliError,
          "unknown option '--$1' (try 'ninfo --help')" % [key])
    of cmdEnd: discard
  if opts.plain:
    opts.noColor = true
  opts

proc usageText*(): string =
  """Usage: ninfo [command] [options]

A fast, lightweight Linux system information tool.

Commands:
  system     Operating system, kernel, architecture, hostname, uptime
  cpu        CPU model, core counts, frequency
  memory     RAM and swap usage
  storage    Mounted filesystems and capacity
  network    Interfaces, addresses, default gateway
  processes  Process counts
  help       Show this help
  version    Show version

Options:
  --json       Output JSON (script-friendly, deterministic)
  --plain      Plain text: no colors, no box drawing
  --no-color   Disable ANSI colors (keeps layout)
  -h, --help   Show this help
  -v, --version  Show version

Examples:
  ninfo                  Show a summary of everything
  ninfo cpu --json       CPU info as JSON
  ninfo storage --plain  Storage without colors

Exit codes:
  0  success
  1  runtime error (data could not be collected)
  2  usage error (bad command or option)"""
