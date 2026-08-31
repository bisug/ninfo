## Filesystem statistics collector (Linux).
##
## Enumerates real mounts from /proc/self/mountinfo (skips pseudo
## filesystems like proc, sysfs, tmpfs, devpts) and calls statvfs(2) on
## each mount point - the same data `df` uses, without shelling out.

import std/[strutils, options, posix, math]
import ../core/types

# Filesystem types that never hold real user data.
const pseudoFsTypes = [
  "proc", "sysfs", "devtmpfs", "devpts", "tmpfs", "squashfs", "overlay",
  "cgroup", "cgroup2", "pstore", "bpf", "tracefs", "debugfs", "configfs",
  "fusectl", "mqueue", "hugetlbfs", "autofs", "binfmt_misc", "ramfs",
  "securityfs", "efivarfs", "fuse.gvfsd-fuse", "fuse.portal", "nsfs",
]

proc isPseudoFs*(fsType: string): bool =
  ## True for virtual/pseudo filesystems that should not be listed.
  fsType in pseudoFsTypes

proc unescapePath*(s: string): string =
  ## Decode mountinfo octal escapes: \040 -> space, \011 -> tab, etc.
  result = newStringOfCap(s.len)
  var i = 0
  while i < s.len:
    if s[i] == '\\' and i + 3 < s.len and s[i+1] == '0':
      try:
        let code = parseOctInt(s[i+1 .. i+3])
        result.add(chr(code))
        inc i, 4
        continue
      except ValueError:
        discard
    result.add(s[i])
    inc i

proc parseMountinfo*(): seq[tuple[device, mountPoint, fsType: string]] =
  ## Parse /proc/self/mountinfo. Each line:
  ##   id parent major:minor root mount_point opts - fstype source super
  ## Returns (device, mountPoint, fsType) for non-pseudo mounts.
  result = @[]
  try:
    for line in readFile("/proc/self/mountinfo").splitLines():
      if line.len == 0:
        continue
      # Fields after the " - " separator hold fstype and source.
      let sep = line.find(" - ")
      if sep < 0:
        continue
      let left = line[0 ..< sep]
      let right = line[sep + 3 ..^ 1]
      let leftFields = left.split(' ')
      let rightFields = right.split(' ')
      # left: id parent major:minor root mount_point [opts...]
      if leftFields.len < 5 or rightFields.len < 2:
        continue
      let mountPoint = unescapePath(leftFields[4])
      let fsType = rightFields[0]
      let device = rightFields[1]
      if isPseudoFs(fsType):
        continue
      result.add((device, mountPoint, fsType))
  except IOError, OSError:
    discard

proc statvfsBytes*(mountPoint: string): Option[tuple[total, used, avail: uint64]] =
  ## statvfs(2) on a mount point. None when the call fails (e.g. the
  ## mount vanished, or permission denied on the superblock).
  var st: Statvfs
  if statvfs(mountPoint.cstring, st) != 0:
    return none(tuple[total, used, avail: uint64])
  let total = st.f_blocks.uint64 * st.f_frsize.uint64
  let avail = st.f_bavail.uint64 * st.f_frsize.uint64
  # Used counts only blocks available to root (f_bfree), matching df.
  let free = st.f_bfree.uint64 * st.f_frsize.uint64
  if total == 0:
    return none(tuple[total, used, avail: uint64])
  let used = total - min(total, free)
  some((total, used, avail))

proc collectFilesystems*(): seq[FilesystemInfo] =
  result = @[]
  for (device, mountPoint, fsType) in parseMountinfo():
    var fs: FilesystemInfo
    fs.device = device
    fs.mountPoint = mountPoint
    fs.fsType = fsType
    let stats = statvfsBytes(mountPoint)
    if stats.isSome:
      let (total, used, avail) = stats.get
      fs.totalBytes = some(total)
      fs.usedBytes = some(used)
      fs.availableBytes = some(avail)
      if total > 0:
        fs.usedPercent = some(round(used.float / total.float * 100.0, 1))
    result.add(fs)
