## JSON renderer.
##
## Deterministic output: fixed key order, null for unavailable values,
## no timestamps or environment-dependent noise. Suitable for scripts.

import std/[json, options]
import ../core/types
import ../cli/options

proc optInt*(o: Option[int]): JsonNode =
  if o.isNone: newJNull() else: newJInt(o.get)

proc optFloat*(o: Option[float]): JsonNode =
  if o.isNone: newJNull() else: newJFloat(o.get)

proc optString*(o: Option[string]): JsonNode =
  if o.isNone: newJNull() else: newJString(o.get())

proc optBytes*(o: Option[uint64]): JsonNode =
  ## Bytes are emitted as integers - scripts can format them.
  if o.isNone: newJNull() else: newJInt(o.get().BiggestInt)

proc systemJson*(sys: SystemInfo): JsonNode =
  %* {
    "os": sys.osName,
    "kernel": sys.kernelVersion,
    "architecture": sys.architecture,
    "hostname": sys.hostname,
    "uptime_seconds": sys.uptimeSeconds
  }

proc cpuJson*(cpu: CpuInfo): JsonNode =
  %* {
    "model": optString(cpu.modelName),
    "physical_cores": optInt(cpu.physicalCores),
    "logical_cores": optInt(cpu.logicalCores),
    "mhz": optFloat(cpu.mhz)
  }

proc memoryJson*(mem: MemoryInfo): JsonNode =
  %* {
    "total_bytes": optBytes(mem.totalBytes),
    "used_bytes": optBytes(mem.usedBytes),
    "available_bytes": optBytes(mem.availableBytes),
    "used_percent": optFloat(mem.usedPercent),
    "swap_total_bytes": optBytes(mem.swapTotalBytes),
    "swap_used_bytes": optBytes(mem.swapUsedBytes)
  }

proc filesystemJson*(fs: FilesystemInfo): JsonNode =
  %* {
    "device": fs.device,
    "mount_point": fs.mountPoint,
    "type": fs.fsType,
    "total_bytes": optBytes(fs.totalBytes),
    "used_bytes": optBytes(fs.usedBytes),
    "available_bytes": optBytes(fs.availableBytes),
    "used_percent": optFloat(fs.usedPercent)
  }

proc filesystemsJson*(fsList: seq[FilesystemInfo]): JsonNode =
  ## The storage array, built once and shared by cmdStorage and cmdAll.
  result = newJArray()
  for fs in fsList:
    result.add(filesystemJson(fs))

proc networkJson*(net: NetworkInfo): JsonNode =
  var ifaces = newJArray()
  for iface in net.interfaces:
    ifaces.add(%* {
      "name": iface.name,
      "ipv4": optString(iface.ipv4),
      "ipv6": optString(iface.ipv6),
      "mac": optString(iface.macAddress),
      "loopback": iface.isLoopback,
      "up": iface.isUp
    })
  %* {
    "interfaces": ifaces,
    "default_gateway": optString(net.defaultGateway)
  }

proc processesJson*(procs: ProcessInfo): JsonNode =
  %* {
    "total": procs.total,
    "running": procs.running,
    "sleeping": procs.sleeping,
    "zombie": procs.zombie
  }

proc sensorReadingJson*(r: SensorReading): JsonNode =
  %* {
    "chip": r.chip,
    "kind": r.kind,
    "label": optString(r.label),
    "number": r.number,
    "value": optFloat(r.value),
    "max": optFloat(r.max),
    "critical": optFloat(r.critical)
  }

proc sensorsJson*(sensors: SensorsInfo): JsonNode =
  ## Readings grouped by chip name, chips in sysfs order.
  var chips = newJObject()
  for r in sensors.readings:
    if r.chip notin chips:
      chips[r.chip] = newJArray()
    chips[r.chip].add(sensorReadingJson(r))
  %* { "chips": chips }

proc batteryJson*(b: BatteryInfo): JsonNode =
  %* {
    "name": b.name,
    "state": optString(b.state),
    "present": b.isPresent,
    "capacity_percent": optFloat(b.capacityPercent),
    "capacity_level": optString(b.capacityLevel),
    "voltage_volts": optFloat(b.voltageVolts),
    "energy_now_wh": optFloat(b.energyNowWh),
    "energy_full_wh": optFloat(b.energyFullWh),
    "energy_design_wh": optFloat(b.energyDesignWh),
    "cycle_count": optInt(b.cycleCount),
    "hours_to_empty": optFloat(b.hoursToEmpty),
    "hours_to_full": optFloat(b.hoursToFull)
  }

proc batteriesJson*(bats: BatteriesInfo): JsonNode =
  result = newJArray()
  for b in bats.batteries:
    result.add(batteryJson(b))

proc renderJson*(sys: SystemInfo, cpu: CpuInfo, mem: MemoryInfo,
                 fsList: seq[FilesystemInfo], net: NetworkInfo,
                 procs: ProcessInfo, sensors: SensorsInfo,
                 batteries: BatteriesInfo, command: Command): string =
  ## Render the requested command's data as JSON.
  case command
  of cmdSystem: systemJson(sys).pretty()
  of cmdCpu: cpuJson(cpu).pretty()
  of cmdMemory: memoryJson(mem).pretty()
  of cmdStorage: filesystemsJson(fsList).pretty()
  of cmdNetwork: networkJson(net).pretty()
  of cmdProcesses: processesJson(procs).pretty()
  of cmdSensors: sensorsJson(sensors).pretty()
  of cmdBattery: batteriesJson(batteries).pretty()
  else:
    # cmdAll: one object with every section.
    let root = %* {
      "system": systemJson(sys),
      "cpu": cpuJson(cpu),
      "memory": memoryJson(mem),
      "storage": filesystemsJson(fsList),
      "network": networkJson(net),
      "processes": processesJson(procs),
      "sensors": sensorsJson(sensors),
      "battery": batteriesJson(batteries)
    }
    root.pretty()
