# Gusjo Data Packages

This directory contains the data handling layer used by examples and ML
helpers in the library.

## Packages

### `Gusjo.Data`

Defined in `gusjo-data.ads` / `gusjo-data.adb`.

This package contains small shared data types and conversion helpers:

- `Column_Kind`: supported dataframe column kinds: integer, float, string.
- `Value_Type`: a tagged value used while inferring CSV column types.
- `Parse_Value`: tries integer, then float, then string.
- conversion helpers such as `To_Integer`, `To_Float`, and `To_String`.

It is intentionally lightweight. It does not own dataframe storage.

### `Gusjo.Data.Column`

Defined in `gusjo-data-column.ads` / `gusjo-data-column.adb`.

This is a generic typed column wrapper around `Gusjo.Ds.Array_List`. The
dataframe instantiates it for:

- `Integer`
- `Float`
- `Unbounded_String`

The column package provides append-style writes for ordinary use and indexed
writes for CSV loading:

- `Append`: append one value.
- `Set_At_Index`: write a value at a row index, growing storage if needed.
- `Set_Preallocated_At_Index`: write at an index only when storage is already
  allocated.
- `Set_Row_Count`: set the logical row count after indexed writes.
- `Delete`: release heap storage owned by the column.

`Set_Preallocated_At_Index` is used by the multithreaded CSV loader because it
does not allocate, resize, or update shared size counters. Workers write
different row indexes into already allocated arrays.

### `Gusjo.Data.Frame`

Defined in `gusjo-data-frame.ads` / `gusjo-data-frame.adb`.

This package provides a heterogeneous dataframe:

- CSV loading with optional headers.
- automatic type inference from the first data row.
- typed accessors such as `Get_Integer`, `Get_Float`, and `Get_String`.
- compact terminal display for very wide dataframes.
- feature and response extraction helpers for ML examples.
- train/test and train/validation/test split helpers.
- explicit `Delete` for releasing dataframe-owned heap storage.

The dataframe stores data column-wise. This is convenient for tabular access,
but very wide image datasets can create many columns and heavy memory traffic.

## CSV Loader Design

`Load_CSV` is optimized for arbitrarily long CSV rows and very wide files.

Important implementation choices:

- Rows are read with `Ada.Strings.Unbounded.Text_IO.Get_Line`, so there is no
  fixed line-size buffer.
- Parsing uses GNAT's `Ada.Strings.Unbounded.Aux.Get_String` to avoid copying
  each huge row before parsing.
- Numeric fields use a fast one-pass parser after column types are known.
- The loader counts data rows first, allocates columns, parses the first data
  row serially to infer column types, then parses remaining rows with a fixed
  worker pool.
- Worker count defaults to `System.Multiprocessors.Number_Of_CPUs`.
- `GUSJO_CSV_WORKERS` can override the worker count at runtime.

Example:

```sh
gnatmake -f -P gusjo.gpr usage_examples/animal_nn.adb -cargs -O3 -march=native -gnatn -gnatp
env GUSJO_CSV_WORKERS=16 time ./obj/animal_nn
```

## Threading And Memory Safety

The array-list and column APIs are not intended to be generally thread-safe for
arbitrary concurrent mutation. The CSV loader uses a narrower safe pattern:

- all columns are allocated before workers start parsing;
- workers call only `Set_Preallocated_At_Index`;
- each worker writes a distinct row index;
- workers do not append, resize, or set logical sizes;
- column row counts are set once after parsing completes;
- queued `Unbounded_String` rows are cleared after consumption or abort;
- dataframe-owned storage is released through `Delete`.

This keeps allocation and metadata mutation out of worker tasks.

## CSV Loading Benchmark

Benchmark target:

- file: `python_comparison/animals.csv`
- approximate size: 33 GB
- rows: 26,179 data rows
- columns: 196,610 columns (`id`, `class_name`, and 196,608 pixels)
- cells parsed: about 5.15 billion
- machine/output shown by local shell timings on Pop!_OS
- optimized build flags: `-O3 -march=native -gnatn -gnatp`

Historical wall-clock results while optimizing the loader:

| Loader/build variant | Wall time |
| --- | ---: |
| Original broad-line loader | 12m18s to 12m55s |
| Single-thread parser with optimized build flags | 7m16s |
| One-pass numeric parser, single thread | 5m31s |
| Multithreaded loader, default workers | 1m16s |

Worker-count tuning results:

| `GUSJO_CSV_WORKERS` | Elapsed | CPU | User | System | Max RSS |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 4 | 2:04.03 | 373% | 423.85s | 39.17s | 20,172,600 KB |
| 8 | 1:20.41 | 680% | 482.80s | 64.32s | 20,191,624 KB |
| 12 | 1:04.36 | 939% | 519.57s | 84.90s | 20,210,708 KB |
| 16 | 1:02.65 | 1193% | 633.08s | 114.94s | 20,231,488 KB |

The higher user time compared with elapsed time shows that parsing is using
multiple CPU cores. The higher system time reflects the extra scheduling,
queueing, and memory traffic from parallel loading.

For this dataset, 12-16 workers performed best in the benchmark above. The
best value may vary by CPU count, memory bandwidth, and other system load.

## Notes

- `Ada.Strings.Unbounded.Aux` is a GNAT-specific internal package. It is used
  intentionally for performance on very wide rows.
- The dataframe representation is general-purpose and column-oriented. For
  image datasets, a future dense matrix loader or binary cache would likely be
  faster and more memory efficient than representing each pixel as a dataframe
  column.
