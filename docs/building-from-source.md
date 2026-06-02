# Building from Source

## Prerequisites

- macOS with Xcode Command Line Tools installed
- `git` and `make`

## Basic Build

```bash
git clone https://github.com/aaabramov/Hoist.git
cd Hoist
make clean && make && make install
```

This builds both the CLI binary and `Hoist.app`, then installs `Hoist.app` to `/Applications`.

## Build Targets

| Command | Description |
|---------|-------------|
| `make` | Build both CLI binary and .app bundle |
| `make test` | Build and run the headless unit-test suite |
| `make clean` | Remove binaries, object files, and .app directories |
| `make install` | Install Hoist.app to `/Applications` |
| `make build` | Clean build with experimental flags |
| `make dev` | Clean build of HoistDev.app (separate bundle ID for parallel testing) |
| `make run` | Dev build and execute |
| `make debug` | Dev build with verbose logging and execute |
| `make update` | Build and install to `/Applications` |

## Compilation Flags

You can enable advanced features by passing flags to `make`:

| Flag | Description |
|------|-------------|
| `ALTERNATIVE_TASK_SWITCHER` | Improves warp accuracy with third-party task switchers (e.g., AltTab). May occasionally cause unexpected mouse warps. |
| `OLD_ACTIVATION_METHOD` | Fixes raising for apps using non-native graphics (GTK, SDL, Wine). Introduces a deprecation warning. |
| `EXPERIMENTAL_FOCUS_FIRST` | Enables focus-before-raise using undocumented private APIs. Allows `focusDelay` support. **No guarantee of future macOS compatibility.** |

### Example

```bash
make CXXFLAGS="-DOLD_ACTIVATION_METHOD -DEXPERIMENTAL_FOCUS_FIRST" && make install
```

## Build Output

After building, you get two binaries:

- **`Hoist`** — Command line version, accepts parameters directly
- **`Hoist.app`** — Menu bar app with GUI configuration

## Running Tests

```bash
make test
```

This compiles a small, dependency-free, headless test binary (`hoist_tests`) from
the pure-logic sources and the suite under `tests/`, then runs it. It exits
non-zero if any test fails. The suite covers config parsing/validation, CLI
override precedence, and bundle-id (`is_pwa`) classification — no GUI session or
Accessibility permission required, so it also runs in CI on every pull request.
