# Contributing to ninfo

Thanks for your interest in improving ninfo!

## Development setup

1. Install [Nim](https://nim-lang.org/install.html) 2.2 or later
   (choosenim is the easiest route: `choosenim stable`).
2. Clone and verify the build:

```sh
git clone https://github.com/bisug/ninfo.git
cd ninfo
nimble test          # unit tests
nimble integration   # builds bin/ninfo and runs CLI tests
nimble build          # release binary
```

All three must pass before a pull request is considered complete.

## Project conventions

- **Nim style**: follow the
  [Nim style guide](https://nim-lang.org/docs/nep1.html). Run
  `nimpretty src/ninfo/module.nim` on files you touch.
- **No external commands.** Collectors must use `/proc`, `/sys` or native
  libc APIs. Never shell out to `ip`, `lscpu`, `free`, `df` or `uname`.
- **Collectors return typed objects** (`src/ninfo/core/types.nim`); fields
  that can be unavailable are `Option[T]`, never sentinel values.
- **Renderers never collect.** `output/` modules take domain objects only.
- **Linux-specific code stays in its collector module.** Do not leak
  platform details into `core/`, `cli/` or `output/`.
- **No new dependencies** without a discussion first. The project is
  standard-library-only by design.
- **No global mutable state.**

## Commit messages

This project uses [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>
```

Types: `feat`, `fix`, `test`, `docs`, `chore`, `refactor`, `ci`.
Scopes: module names (`system`, `cpu`, `memory`, `storage`, `network`,
`process`, `cli`, `output`, `core`).

Examples:

```
feat(network): add default gateway detection
fix(memory): compute used bytes on kernels without MemAvailable
test(storage): add mountinfo escape-sequence tests
docs: expand JSON examples in usage guide
```

Keep commits atomic — one logical change per commit, and the full test
suite green at every commit.

## Pull requests

1. Create a branch from `main`.
2. Make your change with tests:
   - pure parsing/formatting logic → unit test in `tests/unit/`
   - CLI behavior → integration test in `tests/integration/`
3. Ensure `nimble test` and `nimble integration` pass.
4. Update docs (`README.md`, `docs/`) if user-facing behavior changed.
5. Update `CHANGELOG.md` under `[Unreleased]`.
6. Open a PR with a clear description of what and why.

## Testing guidelines

- Do not make assertions depend on a specific machine (exact core counts,
  interface names, gateway values). Assert shape and relationships instead
  (e.g. "physical cores ≤ logical cores").
- Test the unavailable-data path when you add an `Option` field: what does
  the renderer do with `None`?
- Integration tests run the real binary; keep them fast and side-effect
  free.

## Reporting bugs

Open an issue with:
- `ninfo --version` output
- your OS and kernel (`uname -a`)
- the exact command and its full output
- what you expected instead

## License

By contributing, you agree your contributions are licensed under the MIT
License.
