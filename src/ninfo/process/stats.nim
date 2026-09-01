## Process statistics collector (Linux).
##
## Scans /proc for numeric directories (one per process) and reads each
## /proc/<pid>/stat to classify by state. No external commands.

import std/[os, strutils]
import ../core/types

proc classifyStates*(statLines: seq[string]): tuple[total, running, sleeping, zombie: int] =
  ## Classify process states from /proc/<pid>/stat first lines.
  ## Field 3 (index 2 after splitting) is the state character.
  ## Exported for unit tests.
  result = (0, 0, 0, 0)
  for line in statLines:
    if line.len == 0:
      continue
    inc result.total
    # comm (field 2) may contain spaces, so parse from the last ')'.
    let closeParen = line.rfind(')')
    if closeParen < 0 or closeParen + 2 >= line.len:
      continue
    let state = line[closeParen + 2]
    case state
    of 'R': inc result.running
    of 'S': inc result.sleeping
    of 'Z': inc result.zombie
    else: discard

proc collectProcesses*(): ProcessInfo =
  var statLines: seq[string] = @[]
  for kind, name in walkDir("/proc"):
    if kind != pcDir:
      continue
    # walkDir yields full paths like "/proc/123"; keep only the numeric
    # directory names (one per process).
    let base = name.splitPath().tail
    if base.len == 0 or not base.allCharsInSet(Digits):
      continue
    try:
      statLines.add(readFile("/proc/" & base & "/stat"))
    except IOError, OSError:
      # Process may have exited between walkDir and read - skip it.
      discard
  let (total, running, sleeping, zombie) = classifyStates(statLines)
  ProcessInfo(total: total, running: running, sleeping: sleeping, zombie: zombie)
