# Package
version       = "0.1.0"
author        = "Bisu Ghalan"
description   = "A lightweight, fast and professional Linux system information CLI"
license       = "MIT"
srcDir        = "src"
bin           = @["ninfo"]

# Dependencies
requires "nim >= 2.2.0"

skipDirs = @["nimcache", "tests", "docs"]
