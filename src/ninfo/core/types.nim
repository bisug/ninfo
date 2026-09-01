## Core domain types shared across collectors and renderers.
##
## Every collector returns one of the objects below. Fields that may be
## unavailable on some systems are `Option[T]` so renderers can show an
## explicit "n/a" instead of guessing.

import std/options

type
  SystemInfo* = object
    ## Static-ish system identity: OS, kernel, arch, hostname, uptime.
    osName*: string          ## e.g. "Ubuntu 24.04.1 LTS" or "Linux"
    kernelVersion*: string   ## e.g. "6.10.5-100.fc40.x86_64"
    architecture*: string    ## e.g. "x86_64"
    hostname*: string
    uptimeSeconds*: int      ## Seconds since boot; 0 if unknown.

  CpuInfo* = object
    modelName*: Option[string]
    physicalCores*: Option[int]
    logicalCores*: Option[int]
    ## Nominal frequency in MHz when the kernel reports it.
    mhz*: Option[float]

  MemoryInfo* = object
    totalBytes*: Option[uint64]
    usedBytes*: Option[uint64]
    availableBytes*: Option[uint64]
    ## used / total * 100, rounded to one decimal. None when total unknown.
    usedPercent*: Option[float]
    swapTotalBytes*: Option[uint64]
    swapUsedBytes*: Option[uint64]

  FilesystemInfo* = object
    ## One mounted filesystem (from statvfs on a mount point).
    device*: string          ## e.g. "/dev/nvme0n1p1"
    mountPoint*: string      ## e.g. "/"
    fsType*: string          ## e.g. "ext4"
    totalBytes*: Option[uint64]
    usedBytes*: Option[uint64]
    availableBytes*: Option[uint64]
    usedPercent*: Option[float]

  InterfaceInfo* = object
    ## One network interface (from getifaddrs).
    name*: string            ## e.g. "eth0"
    ipv4*: Option[string]
    ipv6*: Option[string]
    macAddress*: Option[string]
    isLoopback*: bool
    isUp*: bool

  NetworkInfo* = object
    interfaces*: seq[InterfaceInfo]
    defaultGateway*: Option[string]

  ProcessInfo* = object
    ## Basic process statistics from /proc.
    total*: int              ## Number of visible processes.
    running*: int            ## Processes in R state.
    sleeping*: int           ## Processes in S state.
    zombie*: int              ## Processes in Z state.

  SensorReading* = object
    ## One sensor value from a hwmon chip.
    ## `label` is the kernel-provided label (e.g. "Core 0"); `kind` is
    ## "temp", "fan", "in" (voltage), "curr" (current) or "power".
    ## Numeric values are None when the chip does not expose them.
    chip*: string            ## hwmon chip name, e.g. "coretemp"
    kind*: string            ## "temp" | "fan" | "in" | "curr" | "power"
    label*: Option[string]   ## e.g. "Package id 0"; None when no _label file
    number*: int             ## Sensor index within the chip, e.g. 1 for temp1
    value*: Option[float]    ## temp: deg C; fan: RPM; in: volts; curr: amps; power: watts
    max*: Option[float]      ## _max threshold, same unit as value
    critical*: Option[float] ## _crit threshold, same unit as value

  SensorsInfo* = object
    ## All sensor readings, grouped by chip in sysfs order.
    readings*: seq[SensorReading]

  BatteryInfo* = object
    ## One battery, from /sys/class/power_supply/<name> with type=Battery.
    ## Energy values are µWh, charge values µAh, voltage µV — all scaled
    ## to Wh/Ah/V by the collector. None when the kernel does not report.
    name*: string             ## e.g. "BAT1"
    state*: Option[string]    ## "Charging" | "Discharging" | "Full" | ...
    isPresent*: bool
    capacityPercent*: Option[float]  ## Kernel-reported 0..100
    capacityLevel*: Option[string]    ## "Full" | "High" | "Normal" | "Low" | "Critical"
    voltageVolts*: Option[float]
    energyNowWh*: Option[float]       ## Or charge-based when the battery reports µAh
    energyFullWh*: Option[float]
    energyDesignWh*: Option[float]
    cycleCount*: Option[int]
    ## Hours until empty/full; None when not discharging/charging or unknown.
    hoursToEmpty*: Option[float]
    hoursToFull*: Option[float]

  BatteriesInfo* = object
    ## All batteries found; empty on desktops — not an error.
    batteries*: seq[BatteryInfo]

  NinfoError* = object of CatchableError
    ## Raised when a collector cannot gather data at all (as opposed to
    ## individual fields being unavailable, which are `Option.none`).
