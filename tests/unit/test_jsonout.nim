## Unit tests for JSON renderer determinism and shape.

import std/[unittest, json, options]
import ninfo/core/types
import ninfo/cli/options
import ninfo/output/jsonout

proc sampleSystem(): SystemInfo =
  SystemInfo(osName: "TestOS", kernelVersion: "1.2.3", architecture: "x86_64",
             hostname: "host", uptimeSeconds: 3600)

proc sampleCpu(): CpuInfo =
  CpuInfo(modelName: some("Test CPU"), physicalCores: some(2),
          logicalCores: some(4), mhz: some(2400.0))

proc sampleMem(): MemoryInfo =
  MemoryInfo(totalBytes: some(1024'u64), usedBytes: some(512'u64),
             availableBytes: some(512'u64), usedPercent: some(50.0),
             swapTotalBytes: none(uint64), swapUsedBytes: none(uint64))

suite "systemJson":
  test "all fields present":
    let j = parseJson(systemJson(sampleSystem()).pretty())
    check j["os"].getStr == "TestOS"
    check j["uptime_seconds"].getInt == 3600

suite "cpuJson":
  test "null for missing values":
    var cpu = sampleCpu()
    cpu.mhz = none(float)
    let j = parseJson(cpuJson(cpu).pretty())
    check j["mhz"].kind == JNull
    check j["logical_cores"].getInt == 4

suite "memoryJson":
  test "swap null when absent":
    let j = parseJson(memoryJson(sampleMem()).pretty())
    check j["swap_total_bytes"].kind == JNull
    check j["total_bytes"].getInt == 1024

suite "filesystemJson":
  test "byte counts are integers":
    var fs = FilesystemInfo(device: "/dev/nvme0n1p1", mountPoint: "/",
                            fsType: "ext4", totalBytes: some(100'u64),
                            usedBytes: some(40'u64),
                            availableBytes: some(60'u64),
                            usedPercent: some(40.0))
    let j = parseJson(filesystemJson(fs).pretty())
    check j["total_bytes"].kind == JInt
    check j["mount_point"].getStr == "/"

suite "renderJson determinism":
  test "same input produces identical output":
    let a = renderJson(sampleSystem(), sampleCpu(), sampleMem(), @[],
                       default(NetworkInfo), default(ProcessInfo),
                       default(SensorsInfo), default(BatteriesInfo), cmdAll)
    let b = renderJson(sampleSystem(), sampleCpu(), sampleMem(), @[],
                       default(NetworkInfo), default(ProcessInfo),
                       default(SensorsInfo), default(BatteriesInfo), cmdAll)
    check a == b
  test "cmdAll includes every section":
    let j = parseJson(renderJson(sampleSystem(), sampleCpu(), sampleMem(),
                                 @[], default(NetworkInfo),
                                 default(ProcessInfo), default(SensorsInfo),
                                 default(BatteriesInfo), cmdAll))
    for key in ["system", "cpu", "memory", "storage", "network", "processes", "sensors", "battery"]:
      check key in j
  test "cmdCpu output is cpu-only":
    let j = parseJson(renderJson(sampleSystem(), sampleCpu(), sampleMem(),
                                 @[], default(NetworkInfo),
                                 default(ProcessInfo), default(SensorsInfo),
                                 default(BatteriesInfo), cmdCpu))
    check "model" in j
    check "os" notin j
