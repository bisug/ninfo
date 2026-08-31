## Unit tests for CLI option parsing.

import std/[unittest, strutils]
import ninfo/cli/options

suite "parseCliOptions":
  test "no args means show all":
    let o = parseCliOptions(@[])
    check o.command == cmdAll
    check not o.json
    check not o.plain
    check not o.noColor

  test "each command name":
    for (name, cmd) in [("system", cmdSystem), ("cpu", cmdCpu),
                        ("memory", cmdMemory), ("storage", cmdStorage),
                        ("network", cmdNetwork), ("processes", cmdProcesses)]:
      check parseCliOptions(@[name]).command == cmd

  test "json flag":
    check parseCliOptions(@["cpu", "--json"]).json
    check parseCliOptions(@["--json", "cpu"]).json

  test "plain implies no-color":
    let o = parseCliOptions(@["--plain"])
    check o.plain
    check o.noColor

  test "no-color alone does not imply plain":
    let o = parseCliOptions(@["--no-color"])
    check o.noColor
    check not o.plain

  test "help flag":
    check parseCliOptions(@["--help"]).command == cmdHelp
    check parseCliOptions(@["-h"]).command == cmdHelp

  test "version flag":
    check parseCliOptions(@["--version"]).command == cmdVersion
    check parseCliOptions(@["-v"]).command == cmdVersion

  test "unknown command raises CliError":
    doAssertRaises CliError:
      discard parseCliOptions(@["bogus"])

  test "unknown option raises CliError":
    doAssertRaises CliError:
      discard parseCliOptions(@["--bogus"])

  test "two commands raise CliError":
    doAssertRaises CliError:
      discard parseCliOptions(@["cpu", "memory"])

suite "usageText":
  test "mentions every command":
    let u = usageText()
    for name in ["system", "cpu", "memory", "storage", "network", "processes"]:
      check name in u
  test "mentions exit codes":
    check "Exit codes" in usageText()