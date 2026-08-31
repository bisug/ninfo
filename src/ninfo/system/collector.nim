## System identity collector (Linux).
##
## Reads /proc and /sys directly - no external commands:
##   - /proc/sys/kernel/osrelease  -> kernel version
##   - /proc/uptime                -> uptime seconds
##   - /proc/sys/kernel/hostname   -> hostname (fallback: gethostname(2))
##   - /etc/os-release             -> pretty OS name
##   - uname(2)                    -> architecture, kernel

import std/[strutils, options, posix]
import ../core/types

proc readFileTrimmed(path: string): Option[string] =
  ## Read a whole file and trim whitespace; None if unreadable.
  try:
    some(readFile(path).strip())
  except IOError, OSError:
    none(string)

proc parseOsRelease*(): Option[string] =
  ## Extract PRETTY_NAME from /etc/os-release (or /usr/lib/os-release).
  ## Falls back to "Linux" when the file is missing or lacks the key.
  for path in ["/etc/os-release", "/usr/lib/os-release"]:
    try:
      for line in readFile(path).splitLines():
        if line.startsWith("PRETTY_NAME="):
          return some(line["PRETTY_NAME=".len..^1].strip(chars = {'"'}))
    except IOError, OSError:
      continue
  none(string)

proc cCharArrayToString*(a: openArray[char]): string =
  ## Convert a fixed C char array (as in Utsname) to a Nim string,
  ## stopping at the first NUL terminator.
  result = ""
  for c in a:
    if c == '\0':
      break
    result.add(c)

proc collectSystem*(): SystemInfo =
  ## Gather system identity. Individual fields degrade to empty/0 when
  ## their source is unavailable rather than failing the whole call.
  var info: SystemInfo

  # uname(2): architecture + kernel release.
  var uts: Utsname
  if uname(uts) == 0:
    info.architecture = cCharArrayToString(uts.machine)
    info.kernelVersion = cCharArrayToString(uts.release)
  else:
    info.architecture = "unknown"

  # OS pretty name.
  info.osName = parseOsRelease().get("Linux")

  # Hostname: prefer /proc, fall back to gethostname(2).
  let hn = readFileTrimmed("/proc/sys/kernel/hostname")
  if hn.isSome and hn.get.len > 0:
    info.hostname = hn.get
  else:
    var buf = newString(256)
    if posix.gethostname(buf.cstring, buf.len) == 0:
      # gethostname NUL-terminates; find the terminator and trim.
      let nul = buf.find('\0')
      if nul >= 0:
        buf.setLen(nul)
      info.hostname = buf
    else:
      info.hostname = "unknown"

  # Uptime: first field of /proc/uptime is seconds since boot.
  let up = readFileTrimmed("/proc/uptime")
  if up.isSome:
    let first = up.get.split(' ')[0]
    try:
      info.uptimeSeconds = parseInt(first.split('.')[0])
    except ValueError:
      info.uptimeSeconds = 0
  info
