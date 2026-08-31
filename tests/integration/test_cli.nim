## Integration tests: run the built ninfo binary and check behavior.
##
## Requires bin/ninfo (built by `nimble integration`).

import std/[unittest, osproc, strutils, json]

const binary = "bin/ninfo"

proc runNinfo*(args: string): tuple[output: string, exitCode: int] =
  let cmd = binary & " " & args
  let (outp, code) = execCmdEx(cmd)
  (outp, code)

suite "CLI integration":
  test "no arguments shows all sections":
    let (res, code) = runNinfo("--no-color")
    check code == 0
    for section in ["System", "CPU", "Memory", "Storage", "Network", "Processes"]:
      check section in res

  test "--version prints version":
    let (res, code) = runNinfo("--version")
    check code == 0
    check res.strip.startsWith("ninfo ")

  test "--help shows usage":
    let (res, code) = runNinfo("--help")
    check code == 0
    check "Usage:" in res
    check "Commands:" in res

  test "unknown command exits 2 with clean message":
    let (res, code) = runNinfo("bogus")
    check code == 2
    check "unknown command" in res
    check "Traceback" notin res

  test "unknown option exits 2 with clean message":
    let (res, code) = runNinfo("--bogus")
    check code == 2
    check "unknown option" in res
    check "Traceback" notin res

  test "two commands rejected":
    let (res, code) = runNinfo("cpu memory")
    check code == 2
    check "unexpected argument" in res

suite "command output":
  test "system shows kernel and hostname":
    let (res, code) = runNinfo("--no-color system")
    check code == 0
    check "Kernel:" in res
    check "Hostname:" in res
    check "Uptime:" in res

  test "cpu shows model":
    let (res, code) = runNinfo("--no-color cpu")
    check code == 0
    check "Model:" in res

  test "memory shows totals":
    let (res, code) = runNinfo("--no-color memory")
    check code == 0
    check "Total:" in res
    check "Usage:" in res

  test "storage lists root filesystem":
    let (res, code) = runNinfo("--no-color storage")
    check code == 0
    check "/" in res

  test "network lists loopback":
    let (res, code) = runNinfo("--no-color network")
    check code == 0
    check "lo" in res
    check "127.0.0.1" in res

  test "processes shows counts":
    let (res, code) = runNinfo("--no-color processes")
    check code == 0
    check "Total:" in res

suite "JSON output":
  test "system json is valid and has expected keys":
    let (res, code) = runNinfo("system --json")
    check code == 0
    let j = parseJson(res)
    check "os" in j
    check "kernel" in j
    check "architecture" in j
    check "hostname" in j
    check "uptime_seconds" in j

  test "all json contains every section":
    let (res, code) = runNinfo("--json")
    check code == 0
    let j = parseJson(res)
    for key in ["system", "cpu", "memory", "storage", "network", "processes"]:
      check key in j

  test "json is deterministic across runs":
    let (a, codeA) = runNinfo("cpu --json")
    let (b, codeB) = runNinfo("cpu --json")
    check codeA == 0
    check codeB == 0
    # Model and core counts are stable between two immediate runs.
    check a == b

  test "storage json is an array":
    let (res, code) = runNinfo("storage --json")
    check code == 0
    let j = parseJson(res)
    check j.kind == JArray
    check j.len > 0
    check "mount_point" in j[0]

  test "network json has interfaces array":
    let (res, code) = runNinfo("network --json")
    check code == 0
    let j = parseJson(res)
    check j["interfaces"].kind == JArray
    check j["interfaces"].len > 0

suite "output flags":
  test "--plain disables ANSI codes":
    let (res, code) = runNinfo("--plain")
    check code == 0
    check "\e[" notin res

  test "--no-color disables ANSI codes":
    let (res, code) = runNinfo("--no-color")
    check code == 0
    check "\e[" notin res

  test "default output may use ANSI codes":
    # Only verifies it does not crash; color presence depends on TTY.
    let (res, code) = runNinfo("cpu")
    check code == 0
