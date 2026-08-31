# ninfo - system information CLI
import ninfo/cli/main

when isMainModule:
  let exitCode = ninfoMain()
  quit(exitCode)
