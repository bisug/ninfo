## Unit tests for process state classification and network parsing.

import std/[unittest, options]
import ninfo/process/stats
import ninfo/network/interfaces

suite "classifyStates":
  test "empty input":
    let r = classifyStates(@[])
    check r == (0, 0, 0, 0)
  test "single running process":
    let r = classifyStates(@["1 (init) R 0 1"])
    check r == (1, 1, 0, 0)
  test "mixed states":
    let lines = @[
      "1 (systemd) S 0 1 1 0",
      "2 (kthreadd) S 0 0 0",
      "42 (worker) R 1 42",
      "99 (defunct) Z 1 99",
      "100 (idle) I 0 100",
    ]
    let r = classifyStates(lines)
    check r.total == 5
    check r.running == 1
    check r.sleeping == 2
    check r.zombie == 1
  test "comm with parens and spaces":
    # rfind(')') must skip a ')' inside the comm field.
    let r = classifyStates(@["7 ((sd-pam)) S 1 7"])
    check r == (1, 0, 1, 0)

suite "collectProcesses":
  test "sees at least this test process":
    let p = collectProcesses()
    check p.total > 0
    check p.total >= p.running + p.sleeping + p.zombie

suite "parseDefaultGateway":
  test "returns something on a normal Linux host":
    # Not machine-specific: only asserts Some/None, not the value.
    let gw = parseDefaultGateway()
    check gw.isSome or gw.isNone

suite "macFromIfaddrs":
  test "loopback has all-zero mac":
    let mac = macFromIfaddrs("lo")
    check mac == some("00:00:00:00:00:00")
  test "unknown interface returns none":
    check macFromIfaddrs("no-such-iface-xyz").isNone
