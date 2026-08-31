## Network interface collector (Linux).
##
## Uses getifaddrs(3) - the same API `ip addr` uses - imported directly
## from glibc since Nim's posix module does not wrap it. The default
## gateway is read from /proc/net/route (no `ip route` shell-out).

import std/[strutils, options, posix, tables]
import ../core/types

# --- getifaddrs binding -------------------------------------------------
# Nim's std/posix does not expose getifaddrs, so bind it directly.
# Layout matches glibc's <ifaddrs.h> on Linux x86_64/aarch64.

type
  Ifaddrs {.importc: "struct ifaddrs", header: "<ifaddrs.h>", pure, final.} = object
    ifa_next*: ptr Ifaddrs
    ifa_name*: cstring
    ifa_flags*: cuint
    ifa_addr*: ptr SockAddr
    ifa_netmask*: ptr SockAddr
    ifa_ifu*: ptr SockAddr   # broadcast or destination address
    ifa_data*: pointer

proc getifaddrs*(ifap: var ptr Ifaddrs): cint
    {.importc: "getifaddrs", header: "<ifaddrs.h>".}
proc freeifaddrs*(ifa: ptr Ifaddrs)
    {.importc: "freeifaddrs", header: "<ifaddrs.h>".}

# --- helpers -------------------------------------------------------------

proc sockAddrToString*(saPtr: ptr SockAddr): Option[string] =
  ## Convert a sockaddr to a printable IP address via inet_ntop.
  ## Returns None for non-IP families (AF_PACKET etc.).
  if saPtr.isNil:
    return none(string)
  var buf: array[46, char]
  let family = saPtr.sa_family.int
  let res =
    if family == AF_INET:
      let sa = cast[ptr Sockaddr_in](saPtr)
      inet_ntop(AF_INET, addr sa.sin_addr, cast[cstring](buf[0].addr), buf.len.int32)
    elif family == AF_INET6:
      let sa = cast[ptr Sockaddr_in6](saPtr)
      inet_ntop(AF_INET6, addr sa.sin6_addr, cast[cstring](buf[0].addr), buf.len.int32)
    else:
      return none(string)
  if not res.isNil: some($res) else: none(string)

proc macFromIfaddrs*(name: string): Option[string] =
  ## Read a MAC address from /sys/class/net/<name>/address.
  ## getifaddrs does not expose link-layer addresses portably, so sysfs
  ## is the least-privilege native source.
  try:
    let mac = readFile("/sys/class/net/" & name & "/address").strip()
    if mac.len == 17 and mac.count(':') == 5:
      some(mac)
    else:
      none(string)
  except IOError, OSError:
    none(string)

proc parseDefaultGateway*(): Option[string] =
  ## Parse the default gateway from /proc/net/route.
  ## Lines: Iface Destination Gateway ... Flags ... Mask ...
  ## The default route has Destination 00000000; Gateway is a hex
  ## little-endian IPv4 address.
  try:
    for line in readFile("/proc/net/route").splitLines():
      let f = line.splitWhitespace()
      # Skip header and non-default routes.
      if f.len < 3 or f[1] != "00000000":
        continue
      let gwHex = f[2]
      if gwHex.len != 8:
        continue
      # Hex is little-endian: AABBCCDD -> D.C.B.A
      let b3 = gwHex[0..1]; let b2 = gwHex[2..3]
      let b1 = gwHex[4..5]; let b0 = gwHex[6..7]
      let b0v = parseHexInt(b0); let b1v = parseHexInt(b1)
      let b2v = parseHexInt(b2); let b3v = parseHexInt(b3)
      return some($b0v & "." & $b1v & "." & $b2v & "." & $b3v)
  except IOError, OSError, ValueError:
    discard
  none(string)

# --- collector ------------------------------------------------------------

proc collectNetwork*(): NetworkInfo =
  var info: NetworkInfo
  info.interfaces = @[]
  info.defaultGateway = parseDefaultGateway()

  var ifap: ptr Ifaddrs = nil
  if getifaddrs(ifap) != 0:
    return info

  # Aggregate addresses per interface name, preserving first-seen order.
  # byName holds pointers into the sequence so updates need no copy.
  var order: seq[string] = @[]
  var byName = initTable[string, int]()

  var cur = ifap
  while not cur.isNil:
    let name = $cur.ifa_name
    if name notin byName:
      order.add(name)
      byName[name] = info.interfaces.len
      var iface: InterfaceInfo
      iface.name = name
      # IFF_UP = 0x1, IFF_LOOPBACK = 0x8
      iface.isUp = (cur.ifa_flags and 0x1) != 0
      iface.isLoopback = (cur.ifa_flags and 0x8) != 0
      info.interfaces.add(iface)
    let idx = byName[name]
    let family = if cur.ifa_addr.isNil: -1 else: cur.ifa_addr.sa_family.int
    if family == AF_INET or family == AF_INET6:
      let addrStr = sockAddrToString(cur.ifa_addr)
      if addrStr.isSome:
        if family == AF_INET and info.interfaces[idx].ipv4.isNone:
          info.interfaces[idx].ipv4 = addrStr
        elif family == AF_INET6 and info.interfaces[idx].ipv6.isNone:
          info.interfaces[idx].ipv6 = addrStr
    cur = cur.ifa_next

  freeifaddrs(ifap)

  for name in order:
    info.interfaces[byName[name]].macAddress = macFromIfaddrs(name)
  info
