## Unit tests for formatting helpers.

import std/[unittest, options]
import ninfo/utils/format

suite "humanBytes":
  test "zero":
    check humanBytes(0'u64) == "0 B"
  test "small bytes":
    check humanBytes(512'u64) == "512 B"
  test "kibibyte":
    check humanBytes(1024'u64) == "1.0 KiB"
  test "fractional kib":
    check humanBytes(1536'u64) == "1.5 KiB"
  test "mebibyte":
    check humanBytes(1024'u64 * 1024) == "1.0 MiB"
  test "gibibyte":
    check humanBytes(1024'u64 * 1024 * 1024) == "1.0 GiB"
  test "large value caps at PiB":
    check humanBytes(1024'u64 * 1024 * 1024 * 1024 * 1024) == "1.0 PiB"

suite "humanUptime":
  test "zero":
    check humanUptime(0) == "0m"
  test "minutes only":
    check humanUptime(300) == "5m"
  test "hours and minutes":
    check humanUptime(7 * 3600 + 58 * 60) == "7h 58m"
  test "days hours minutes":
    check humanUptime(2 * 86400 + 3 * 3600 + 4 * 60) == "2d 3h 4m"
  test "negative is n/a":
    check humanUptime(-1) == "n/a"

suite "percentString":
  test "none":
    check percentString(none(float)) == "n/a"
  test "value":
    check percentString(some(50.8)) == "39.7%"
  test "rounds to one decimal":
    check percentString(some(33.33333)) == "33.3%"

suite "orNa":
  test "string option":
    check orNa(some("x")) == "x"
    check orNa(none(string)) == "n/a"
  test "int option":
    check orNa(some(4)) == "4"
    check orNa(none(int)) == "n/a"
  test "uint64 option renders human bytes":
    check orNa(some(1024'u64)) == "1.0 KiB"
    check orNa(none(uint64)) == "n/a"
  test "float option":
    check orNa(some(2600.0)) == "2600.0"
    check orNa(none(float)) == "n/a"
