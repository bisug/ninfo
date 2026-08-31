## Unit tests for filesystem parsing helpers.

import std/[unittest, options, sequtils]
import ninfo/storage/filesystems

suite "isPseudoFs":
  test "pseudo types":
    for t in ["proc", "sysfs", "tmpfs", "devpts", "overlay", "cgroup2"]:
      check isPseudoFs(t)
  test "real types":
    for t in ["ext4", "btrfs", "xfs", "vfat", "ntfs3", "f2fs"]:
      check not isPseudoFs(t)

suite "unescapePath":
  test "plain path unchanged":
    check unescapePath("/home/user") == "/home/user"
  test "space escape":
    check unescapePath("/mnt/My\\040Drive") == "/mnt/My Drive"
  test "tab escape":
    check unescapePath("/a\\011b") == "/a\tb"
  test "backslash without octal kept":
    check unescapePath("/a\\xb") == "/a\\xb"
  test "truncated escape kept":
    check unescapePath("/a\\04") == "/a\\04"

suite "parseMountinfo":
  test "returns non-empty list on Linux":
    let mounts = parseMountinfo()
    check mounts.len > 0
  test "root mount present with real fs":
    let mounts = parseMountinfo()
    let root = mounts.filterIt(it.mountPoint == "/")
    check root.len == 1
    check not isPseudoFs(root[0].fsType)
  test "no pseudo filesystems in result":
    for m in parseMountinfo():
      check not isPseudoFs(m.fsType)

suite "statvfsBytes":
  test "root filesystem has capacity":
    let r = statvfsBytes("/")
    check r.isSome
    check r.get[0] > 0'u64    # total
    check r.get[1] <= r.get[0]  # used <= total
    check r.get[2] <= r.get[0]  # avail <= total
  test "nonexistent path returns none":
    check statvfsBytes("/nonexistent/path/xyz").isNone
