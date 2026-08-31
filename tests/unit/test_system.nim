## Unit tests for system collector helpers.

import std/[unittest, options]
import ninfo/system/collector

suite "cCharArrayToString":
  test "stops at NUL":
    var arr: array[8, char] = ['a', 'b', 'c', '\0', 'x', 'x', 'x', 'x']
    check cCharArrayToString(arr) == "abc"
  test "no NUL returns whole array":
    var arr: array[3, char] = ['a', 'b', 'c']
    check cCharArrayToString(arr) == "abc"
  test "empty at first NUL":
    var arr: array[4, char] = ['\0', 'a', 'b', 'c']
    check cCharArrayToString(arr) == ""

suite "parseOsRelease":
  test "returns a name on Linux":
    let name = parseOsRelease()
    check name.isSome
    check name.get.len > 0

suite "collectSystem":
  test "collects plausible values":
    let s = collectSystem()
    check s.osName.len > 0
    check s.kernelVersion.len > 0
    check s.architecture.len > 0
    check s.hostname.len > 0
    check s.uptimeSeconds >= 0
  test "architecture has no NUL bytes":
    let s = collectSystem()
    check '\0' notin s.architecture
    check '\0' notin s.kernelVersion
