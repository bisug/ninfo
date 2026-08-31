# Build/test configuration for ninfo.
# Loaded automatically by Nim for files in this project.

# Add src/ to the module search path so tests can import ninfo/*.
switch("path", "src")

# Warnings that catch real bugs in this codebase.
switch("warningAsError", "UnusedImport")
switch("warningAsError", "PtrToCstringConv")
