## Formatting helpers shared by renderers.
##
## Pure functions only - no I/O, no globals - so they are trivially testable.

import std/[strutils, strformat, options]

func humanBytes*(bytes: uint64): string =
  ## Format bytes as a human-readable binary (KiB/MiB/GiB) string.
  ## 0 -> "0 B"; 512 -> "512 B"; 1536 -> "1.5 KiB".
  const units = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"]
  if bytes == 0:
    return "0 B"
  var size = float(bytes)
  var unit = 0
  while size >= 1024.0 and unit < units.high:
    size /= 1024.0
    inc unit
  if unit == 0:
    $bytes & " B"
  else:
    fmt"{size:.1f} {units[unit]}"

func humanUptime*(seconds: int): string =
  ## Format seconds as "Xd Yh Zm" (days/hours/minutes, largest first).
  if seconds < 0:
    return "n/a"
  if seconds == 0:
    return "0m"
  let days = seconds div 86400
  let hours = (seconds mod 86400) div 3600
  let minutes = (seconds mod 3600) div 60
  var parts: seq[string] = @[]
  if days > 0: parts.add($days & "d")
  if hours > 0 or days > 0: parts.add($hours & "h")
  parts.add($minutes & "m")
  parts.join(" ")

func percentString*(p: Option[float]): string =
  ## Render a percentage option as "12.3%" or "n/a".
  if p.isNone: "n/a" else: fmt"{p.get():.1f}%"

func orNa*(s: Option[string]): string =
  ## Unwrap a string option or "n/a".
  if s.isNone: "n/a" else: s.get()

func orNa*(i: Option[int]): string =
  if i.isNone: "n/a" else: $i.get()

func orNa*(b: Option[uint64]): string =
  if b.isNone: "n/a" else: humanBytes(b.get())

func orNa*(f: Option[float]): string =
  if f.isNone: "n/a" else: fmt"{f.get():.1f}"
