# Gusjo

Gusjo is a small Ada library I use to explore Ada concepts through code. The project grew out of my education and later parts of my coding career, which started with the introductory programming course in Ada at LiU.

The goal is not just to collect utility code, but to learn how the pieces fit together: packages, private types, generic programming, linear algebra, data structures, I/O, and a small neural-network module.

## What Is Included

- `gusjo.ads` / `gusjo.adb`: top-level package entry points.
- `math/`: matrix and linear-algebra helpers.
- `ds/`: data structures such as stack, queue, linked list, and heap.
- `io/`: I/O helpers.
- `ai/`: neural-network and neuron code.
- `usage_examples/`: small runnable programs that show how to use the library.

## Requirements

- GNAT Ada compiler and tools.
- A shell with `gnatmake` available on `PATH`.

The project file in this repository is set up for GNAT and uses `obj/` as the build output directory.

## Build

From the repository root, build a program with:

```bash
gnatmake -P gusjo.gpr nn.adb
```

You can also build the other examples the same way:

```bash
gnatmake -P gusjo.gpr math.adb
gnatmake -P gusjo.gpr datastructure.adb
```

If you prefer `gnatmake` without a project file, you need to pass the source directories manually, for example:

```bash
gnatmake -I. -Iai -Imath -Ids -Iio -Iusage_examples nn.adb
```

## Run

After building, run the generated executable from the repository root or from `obj/` depending on how your toolchain is configured.

For the neural-network example:

```bash
./obj/nn
```

If your build places the executable somewhere else, use that path instead.

## Project Layout Notes

The repository keeps `obj/.gitkeep` so the build directory exists after cloning, while `.gitignore` excludes generated build artifacts inside `obj/`.

## Current Focus

This project is meant as a learning workspace. The code is intentionally practical and exploratory, and it is expected to grow over time as new Ada ideas are implemented and tested.
