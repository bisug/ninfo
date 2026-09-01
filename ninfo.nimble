# Package
version       = "0.1.0"
author        = "Bisu Ghalan"
description   = "A lightweight, fast and professional Linux system information CLI"
license       = "MIT"
srcDir        = "src"
bin           = @["ninfo"]

# Dependencies
requires "nim >= 2.2.0"

skipDirs = @["nimcache", "docs"]

# Run unit tests with: nimble test
task test, "Run unit tests":
  exec "nim c --verbosity:0 --hints:off -r -d:ssl tests/unit/test_format.nim"
  exec "nim c --verbosity:0 --hints:off -r tests/unit/test_memory.nim"
  exec "nim c --verbosity:0 --hints:off -r tests/unit/test_options.nim"
  exec "nim c --verbosity:0 --hints:off -r tests/unit/test_filesystems.nim"
  exec "nim c --verbosity:0 --hints:off -r tests/unit/test_process_network.nim"
  exec "nim c --verbosity:0 --hints:off -r tests/unit/test_jsonout.nim"
  exec "nim c --verbosity:0 --hints:off -r tests/unit/test_system.nim"
  exec "nim c --verbosity:0 --hints:off -r tests/unit/test_cpu.nim"
  exec "nim c --verbosity:0 --hints:off -r tests/unit/test_sensors.nim"
  exec "nim c --verbosity:0 --hints:off -r tests/unit/test_battery.nim"

# Run integration tests (requires the binary built first).
task integration, "Run CLI integration tests":
  exec "nim c --verbosity:0 --hints:off -o:bin/ninfo src/ninfo.nim"
  exec "nim c --verbosity:0 --hints:off -r tests/integration/test_cli.nim"

task build, "Build release binary":
  exec "nim c --verbosity:0 --hints:off -d:release -o:bin/ninfo src/ninfo.nim"
