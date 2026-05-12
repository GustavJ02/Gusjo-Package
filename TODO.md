# Gusjo Package – Code Review TODO

This document summarizes a code review of the `Gusjo-Package` Ada repository and converts the findings into a practical implementation roadmap.

The project is a learning-oriented Ada library containing:
- linear algebra primitives,
- data structures,
- dataframe/CSV utilities,
- and a small neural-network module.

The current implementation is already usable for experiments and shows very strong performance improvements when compiled with optimization flags. The main next step is to improve correctness, ownership, memory safety, and test coverage so the project becomes easier to extend.

---

## 1. Current benchmark results

Benchmark command pattern:

```bash
hyperfine './obj/iris_nn'
```

Measured results from the Iris neural-network classifier example:

| Build flags | Mean runtime | Approx. speedup vs baseline |
|---|---:|---:|
| default build | 257.3 ms | 1.0x |
| `-O3` | 30.7 ms | 8.4x |
| `-O3 -march=native` | 31.1 ms | 8.3x |
| `-O3 -march=native -gnatn` | 30.1 ms | 8.5x |
| `-O3 -march=native -gnatn -gnatp` | 28.4 ms | 9.1x |

Main conclusion:

```text
Most of the speedup comes from -O3.
-march=native and -gnatn give only small changes for this workload.
-gnatp gives a small additional improvement, but should not be enabled by default until the library has stronger tests.
```

Recommended release build for now:

```bash
gnatmake -P gusjo.gpr usage_examples/iris_nn.adb -cargs -O3 -march=native -gnatn -largs
```

Use `-gnatp` only for controlled benchmark experiments after fixing warnings and adding tests.

---

## 2. Highest-priority correctness fixes

### 2.1 Fix `Confusion_Matrix`

Current problem areas:
- `Unique_Labels` is allocated as `Predicted'Length`, but unique labels are collected from both `Predicted` and `Actual`.
- The function assumes `Predicted` and `Actual` have the same index range, not just the same length.
- The temporary matrix is heap-allocated and not freed.
- Current orientation is rows = predicted, columns = actual. That is not wrong, but many libraries use rows = actual, columns = predicted.

Recommended approach:

```ada
function Confusion_Matrix(Predicted, Actual : Indices_Array) return Matrix is
begin
   if Predicted'Length /= Actual'Length then
      raise Constraint_Error with "Predicted and Actual must have same length";
   end if;

   if Predicted'Length = 0 then
      return Zeros(1, 1);
   end if;

   declare
      Max_Labels : constant Positive := Predicted'Length + Actual'Length;

      Unique_Labels : Indices_Array(1 .. Max_Labels) := (others => 1);
      Count         : Natural := 0;

      procedure Add_Label(Label : Positive) is
      begin
         for J in 1 .. Count loop
            if Unique_Labels(J) = Label then
               return;
            end if;
         end loop;

         Count := Count + 1;
         Unique_Labels(Count) := Label;
      end Add_Label;

      function Find_Index(L : Positive) return Positive is
      begin
         for K in 1 .. Count loop
            if Unique_Labels(K) = L then
               return K;
            end if;
         end loop;

         raise Constraint_Error with "Label not found in Unique_Labels";
      end Find_Index;

   begin
      for I in Predicted'Range loop
         Add_Label(Predicted(I));
      end loop;

      for I in Actual'Range loop
         Add_Label(Actual(I));
      end loop;

      declare
         type Temp_Matrix is array (Positive range <>, Positive range <>) of Float;

         Temp : Temp_Matrix(1 .. Count, 1 .. Count) :=
           (others => (others => 0.0));

      begin
         for Offset in 0 .. Predicted'Length - 1 loop
            declare
               P_Label : constant Positive :=
                 Predicted(Predicted'First + Offset);

               A_Label : constant Positive :=
                 Actual(Actual'First + Offset);

               P_Idx : constant Positive := Find_Index(P_Label);
               A_Idx : constant Positive := Find_Index(A_Label);
            begin
               -- sklearn-style orientation:
               -- rows = actual, columns = predicted
               Temp(A_Idx, P_Idx) := Temp(A_Idx, P_Idx) + 1.0;
            end;
         end loop;

         declare
            CVs : Column_Vector_Array(1 .. Count);
         begin
            for J in 1 .. Count loop
               declare
                  Values : Float_Array(1 .. Count);
               begin
                  for I in 1 .. Count loop
                     Values(I) := Temp(I, J);
                  end loop;

                  CVs(J) := Column_Vector_From_Array(Values);
               end;
            end loop;

            return HStack_Columns(CVs);
         end;
      end;
   end;
end Confusion_Matrix;
```

Checklist:
- [ ] Allocate label buffer using `Predicted'Length + Actual'Length`.
- [ ] Avoid heap allocation for the temporary count matrix.
- [ ] Iterate by offset when indexing both arrays.
- [ ] Decide and document confusion matrix orientation.
- [ ] Add tests for:
  - perfect classification,
  - missing predicted class,
  - missing actual class,
  - arrays with different lower bounds,
  - empty arrays if supported.

---

### 2.2 Fix `Identity_Matrix`

Current issue:

```ada
Result := new Matrix_Type(1..N, 1..N);

for I in 1..N loop
   Result(I, I) := 1.0;
end loop;
```

Only diagonal values are initialized. Off-diagonal values are undefined.

Recommended fix:

```ada
function Identity_Matrix(N : in Positive) return Matrix is
   Result : Matrix := Zeros(N, N);
begin
   for I in 1 .. N loop
      Result(I, I) := 1.0;
   end loop;

   return Result;
end Identity_Matrix;
```

Checklist:
- [ ] Initialize all values.
- [ ] Add unit test verifying all off-diagonal values are `0.0`.

---

### 2.3 Fix sigmoid derivative when using cached activations

Current issue:

`Derivative_From_A` says it uses activation values `A`, but for sigmoid it calls `Sigmoid_Derivative`, which expects pre-activation `Z`.

Correct derivative if `A = sigmoid(Z)`:

```text
d/dZ sigmoid(Z) = A * (1 - A)
```

Recommended addition:

```ada
function Sigmoid_Derivative_From_A(A : Float) return Float is
begin
   return A * (1.0 - A);
end Sigmoid_Derivative_From_A;
```

Then use it in `Derivative_From_A` and in batch backprop:

```ada
when Sigmoid =>
   Map_In_Place(D, Sigmoid_Derivative_From_A'Access);
```

Checklist:
- [ ] Add `Sigmoid_Derivative_From_A`.
- [ ] Use it wherever the derivative input is already activation `A`.
- [ ] Keep `Sigmoid_Derivative` only for cases where the input is pre-activation `Z`.
- [ ] Add tests comparing numerical gradient vs analytical derivative.

---

### 2.4 Fix `Accuracy`

Current issue:
- `Accuracy` assumes `Predicted` and `Actual` have the same range.
- It does not check equal lengths.
- It divides by `Predicted'Length`, so empty arrays would fail.

Recommended structure:

```ada
function Accuracy(Predicted, Actual : Indices_Array) return Float is
   Correct : Natural := 0;
begin
   if Predicted'Length /= Actual'Length then
      raise Constraint_Error with "Predicted and Actual must have same length";
   end if;

   if Predicted'Length = 0 then
      raise Constraint_Error with "Accuracy: empty input";
   end if;

   for Offset in 0 .. Predicted'Length - 1 loop
      if Predicted(Predicted'First + Offset) =
         Actual(Actual'First + Offset)
      then
         Correct := Correct + 1;
      end if;
   end loop;

   return Float(Correct) / Float(Predicted'Length);
end Accuracy;
```

Checklist:
- [ ] Validate lengths.
- [ ] Decide whether empty arrays should raise or return `0.0`.
- [ ] Iterate by offset, not one array’s range.

---

### 2.5 Fix gradient clipping division in `Step`

Current issue:

```ada
Scale := Clip_Threshold / Norm;
```

This is computed before checking whether clipping is needed. If `Norm = 0.0`, this can produce invalid floating behavior.

Recommended structure:

```ada
if Clip_Threshold > 0.0 and then Norm > Clip_Threshold then
   declare
      Scale : constant Float := Clip_Threshold / Norm;
   begin
      Scale_In_Place(L.dW, Scale);
      Scale_In_Place(L.dB, Scale);
   end;
end if;
```

Checklist:
- [ ] Move scale calculation inside the clipping branch.
- [ ] Add test with zero gradients.
- [ ] Add test with gradients below threshold.
- [ ] Add test with gradients above threshold.

---

## 3. Memory ownership and safety

### 3.1 Core design issue: `Matrix`, `Row_Vector`, and `Column_Vector` are raw access types

Current design:

```ada
type Matrix is access Matrix_Type;
type Row_Vector is access Matrix_Type;
type Column_Vector is access Matrix_Type;
```

This means assignment is shallow:

```ada
A : Matrix := B;
```

Now `A` and `B` point to the same allocation.

Risks:
- accidental aliasing,
- double-free if both are deleted,
- leaks if overwritten without deletion,
- difficult reasoning about ownership,
- expression temporaries are easy to lose.

Possible long-term designs:

#### Option A: Controlled owning type

```ada
type Matrix is new Ada.Finalization.Controlled with private;
```

Implement:
- `Initialize`,
- `Adjust` for deep copy,
- `Finalize` for deallocation.

Pros:
- safer assignment semantics,
- automatic cleanup.

Cons:
- more advanced Ada,
- possible hidden copies if not careful.

#### Option B: Limited owning type

```ada
type Matrix is limited private;
```

Pros:
- prevents accidental copying,
- forces explicit `Copy`.

Cons:
- less convenient API,
- requires more output-parameter style code.

#### Option C: Keep access type but document strict ownership

Pros:
- least rewrite now.

Cons:
- fragile as the library grows.

Recommendation:
For a learning project, continue with access types short-term, but move toward either controlled or limited types before adding more functionality.

Checklist:
- [ ] Decide ownership model.
- [ ] Document who owns returned matrices.
- [ ] Document which procedures mutate in place.
- [ ] Avoid assigning owning records unless intended.
- [ ] Add `Copy` whenever ownership transfer is not intended.

---

### 3.2 Fix `Free_One_Layer`

Current `Dense_Layer` contains:

```ada
W, B        : Matrix;
Z, A        : Column_Vector;
dW, dB      : Matrix;
dA          : Column_Vector;
A_M, Z_M    : Matrix;
```

But the cleanup procedure does not delete `A_M` or `Z_M`.

Recommended fix:

```ada
procedure Free_One_Layer(L : in out Dense_Layer) is
begin
   Delete(L.W);
   Delete(L.B);
   Delete(L.Z);
   Delete(L.A);
   Delete(L.dW);
   Delete(L.dB);
   Delete(L.dA);
   Delete(L.A_M);
   Delete(L.Z_M);
end Free_One_Layer;
```

Checklist:
- [ ] Delete `A_M`.
- [ ] Delete `Z_M`.
- [ ] Remove `Z_M` entirely if unused.
- [ ] Run a repeated train/clear benchmark under Valgrind or GNAT memory checks if available.

---

### 3.3 Avoid expression temporaries in matrix operations

Current pattern:

```ada
dW : Matrix := (dZ * Transpose(A_prev)) * (1.0 / B);
```

Problems:
- `Transpose(A_prev)` allocates a matrix that is not deleted.
- `dZ * Transpose(A_prev)` allocates an intermediate matrix that is not deleted.
- scalar multiplication allocates another matrix.

Safer pattern:

```ada
declare
   A_T  : Matrix := Transpose(A_prev);
   Prod : Matrix := dZ * A_T;
   dW   : Matrix := Prod * (1.0 / B);
begin
   Delete(A_T);
   Delete(Prod);

   Delete(L.dW);
   L.dW := dW;
end;
```

Better long-term pattern:

```ada
procedure Matmul
  (A   : in     Matrix;
   B   : in     Matrix;
   Out : in out Matrix);
```

or:

```ada
procedure Matmul_Transpose_Right
  (Left  : in     Matrix;
   Right : in     Matrix;
   Out   : in out Matrix;
   Scale : in     Float := 1.0);
```

Checklist:
- [ ] Search for nested matrix expressions.
- [ ] Rewrite them using named temporaries and explicit `Delete`.
- [ ] Add in-place/output-buffer kernels for hot paths.
- [ ] Avoid allocating inside every training epoch where possible.

---

### 3.4 Prefer `renames` over shallow local layer copies

Current pattern in places like `Step`:

```ada
L := M.Ls(I);
-- mutate L
M.Ls(I) := L;
```

This shallow-copies all matrix/vector pointers.

Prefer:

```ada
for I in M.Ls'Range loop
   declare
      L : Dense_Layer renames M.Ls(I);
   begin
      -- mutate L directly
   end;
end loop;
```

Checklist:
- [ ] Replace shallow layer copies with `renames`.
- [ ] Avoid local `Dense_Layer` variables unless you are intentionally copying references.
- [ ] Add comments where ownership transfer is intentional.

---

## 4. Neural-network module improvements

### 4.1 Make `Backward_Batch` respect `Loss_Kind`

Current batch path effectively assumes:

```text
dZ = A - Y
```

That is correct for:
- Softmax + CrossEntropy,
- often Sigmoid + CrossEntropy.

It is not generally correct for MSE or arbitrary activation/loss combinations.

Short-term fix:

```ada
if M.Loss /= CrossEntropy or else
   not (L_last.Activation = Softmax or else L_last.Activation = Sigmoid)
then
   raise Constraint_Error with
      "Backward_Batch currently only supports CrossEntropy with Softmax/Sigmoid output";
end if;
```

Long-term fix:
- implement a matrix version of `Compute_dZ_Last`.

Checklist:
- [ ] Add guard in `Backward_Batch`.
- [ ] Implement batch `Compute_dZ_Last`.
- [ ] Add tests for supported loss/activation combinations.
- [ ] Add clear error for unsupported combinations.

---

### 4.2 Add dimension checks in NN operations

Add explicit checks for:
- input dimension matches first layer input size,
- target dimension matches output size,
- batch sizes match,
- model has at least one layer,
- final activation and loss combination is valid.

Checklist:
- [ ] `Forward`: check model/layer dimensions.
- [ ] `Forward_Batch`: check `Rows(X) = Cols(W_first)`.
- [ ] `Backward_Batch`: check `Rows(Y) = output size`.
- [ ] `Backward_Batch`: check `Cols(X) = Cols(Y)`.
- [ ] `Train_Batch`: check `Epochs >= 0`.

---

### 4.3 Add deterministic initialization

Current random initialization resets a local random generator inside `Fill_Random_Uniform`.

Recommended API direction:

```ada
procedure Set_Seed(Seed : Integer);
```

or:

```ada
type Random_State is private;

procedure Reset(State : in out Random_State; Seed : Integer);

procedure Fill_Random_Uniform
  (M          : in out Matrix;
   Low, High  : in     Float;
   State      : in out Random_State);
```

Checklist:
- [ ] Add seedable random generator.
- [ ] Allow deterministic network initialization.
- [ ] Allow deterministic train/test splits.
- [ ] Include seed in examples for reproducible benchmarks.

---

### 4.4 Save/load hardening

Current save/load is a useful start. Improvements:
- validate matrix dimensions when loading bias vectors,
- validate layer compatibility between adjacent layers,
- handle malformed files with useful error messages,
- avoid catching `others` unless rethrowing details,
- version the file format more explicitly.

Checklist:
- [ ] Validate `B` has shape `Outputs x 1`.
- [ ] Validate next layer input matches previous output.
- [ ] Add save/load roundtrip test.
- [ ] Add malformed file tests.

---

## 5. Linear algebra improvements

### 5.1 Use output-buffer operations for performance

Current operators allocate new matrices:

```ada
C := A * B;
D := A + B;
E := Transpose(A);
```

That is convenient but expensive in training loops.

Add procedures:

```ada
procedure Matmul
  (A   : in     Matrix;
   B   : in     Matrix;
   Out : in out Matrix);

procedure Add
  (A   : in     Matrix;
   B   : in     Matrix;
   Out : in out Matrix);

procedure Scale
  (A     : in     Matrix;
   Alpha : in     Float;
   Out   : in out Matrix);
```

Checklist:
- [ ] Add `Matmul(A, B, Out)`.
- [ ] Add `Add(A, B, Out)`.
- [ ] Add `Sub(A, B, Out)`.
- [ ] Add `Scale(A, Alpha, Out)`.
- [ ] Add `Transpose(A, Out)`.
- [ ] Use these in NN training.

---

### 5.2 Consider flat matrix storage

Current `Matrix_Type` is a 2D array:

```ada
type Matrix_Type is array(Natural range <>, Natural range <>) of Float;
```

This is fine, but a flat array can make ownership, cache locality, and BLAS integration easier.

Possible future representation:

```ada
type Float_Buffer is array (Positive range <>) of Float;
type Float_Buffer_Access is access Float_Buffer;

type Matrix is record
   Row_Count : Positive;
   Col_Count : Positive;
   Data      : Float_Buffer_Access;
end record;
```

Index helper:

```ada
function Index(M : Matrix; Row, Col : Positive) return Positive is
begin
   return (Row - 1) * M.Col_Count + Col;
end Index;
```

Checklist:
- [ ] Decide whether current 2D array is sufficient.
- [ ] If performance becomes important, prototype flat storage.
- [ ] Benchmark flat storage vs current 2D access array.

---

### 5.3 Matrix multiplication loop order

Current multiplication is conceptually:

```ada
for I in rows(A) loop
   for K in cols(B) loop
      Sum := 0.0;
      for J in cols(A) loop
         Sum := Sum + A(I, J) * B(J, K);
      end loop;
      C(I, K) := Sum;
   end loop;
end loop;
```

This is correct, but not cache-optimal for large matrices.

Future improvements:
- loop reordering,
- blocking/tiling,
- specialized matrix-vector path,
- BLAS backend.

Checklist:
- [ ] Add benchmark for matrix multiplication sizes: 10, 50, 100, 500.
- [ ] Compare loop orders.
- [ ] Consider linking to BLAS later.

---

### 5.4 Determinant and inverse

Current determinant uses recursive cofactor expansion. That is fine for learning, but exponential for larger matrices.

Future direction:
- determinant via LU decomposition,
- inverse via Gaussian elimination or LU,
- avoid computing `Det(Item)` twice in `Inverse`.

Checklist:
- [ ] Document that current determinant/inverse are educational and only suitable for small matrices.
- [ ] Replace with LU-based methods later.
- [ ] Add tests for known small matrices.

---

## 6. DataFrame and CSV improvements

### 6.1 Add lifecycle management for `DataFrame_Type`

Current dataframe stores access values to columns. Returning dataframes by value creates shallow copies of column pointers.

Add:

```ada
procedure Clear(DF : in out DataFrame_Type);
```

Checklist:
- [ ] Implement `Clear` for dataframe columns.
- [ ] Implement `Clear` for generic column storage.
- [ ] Be careful with shallow copies from `Train(Split)` and `Test(Split)`.
- [ ] Decide whether `DataFrame_Type` should become limited or controlled.

---

### 6.2 Add seed support to train/test split

Current split shuffles rows internally with a local RNG.

Recommended API:

```ada
function Split
  (DF          : DataFrame_Type;
   Train_Ratio : Float;
   Seed        : Integer) return Train_Test_Split_Type;
```

Checklist:
- [ ] Add seed parameter.
- [ ] Preserve existing API with random split.
- [ ] Use seeded split in benchmarks.
- [ ] Add reproducibility test.

---

### 6.3 Improve CSV reader robustness

Current limitations:
- fixed 1000-character line buffer,
- simple quote handling,
- type inference from first data row,
- generic `"Error reading CSV file"` hides useful details,
- long lines may fail.

Checklist:
- [ ] Support longer lines, possibly via `Ada.Strings.Unbounded`.
- [ ] Preserve original exception message where possible.
- [ ] Validate column count and report row number.
- [ ] Decide how to handle missing values.
- [ ] Decide whether quoted delimiters and escaped quotes should be fully supported.
- [ ] Consider explicit schema support instead of only first-row type inference.

---

### 6.4 Avoid leaking feature matrix intermediate vectors

`Feature_Matrix` creates one `Column_Vector` per row and then stacks them with `HStack_Columns`.

After `HStack_Columns`, the temporary column vectors should be deleted.

Recommended pattern:

```ada
declare
   Result : Matrix := HStack_Columns(Samples);
begin
   for I in Samples'Range loop
      Delete(Samples(I));
   end loop;

   return Result;
end;
```

Checklist:
- [ ] Delete temporary column vectors after stacking.
- [ ] Do similar cleanup wherever temporary vector arrays are used.
- [ ] Add memory-leak regression test if possible.

---

## 7. Data structures

### 7.1 `Array_List` needs cleanup/copy semantics

Current `Array_List_Type` owns an access pointer but exposes no `Clear`.

Add:

```ada
procedure Clear(List : in out Array_List_Type);
function Copy(List : Array_List_Type) return Array_List_Type;
```

or make it controlled/limited.

Checklist:
- [ ] Add `Clear`.
- [ ] Add tests for insert, resize, get, clear.
- [ ] Consider using `Ada.Containers.Vectors` for production-style code.
- [ ] Document whether assignment is shallow or forbidden.

---

### 7.2 Index types

Some APIs use `Integer` for indexes, others use `Positive`.

Recommendation:
- use `Positive` for public 1-based indexes,
- use `Natural` for counts,
- avoid accepting negative indexes unless intentional.

Checklist:
- [ ] Change `Get_Element_At_Index(Index : Integer)` to `Positive`.
- [ ] Review all index parameters.
- [ ] Standardize naming: `Index`, `Row`, `Col`, `Count`.

---

## 8. Top-level `Gusjo` package

### 8.1 Remove mixed Integer/Float arithmetic overloads

The top-level package defines overloads such as:

```ada
function "*" (Left : Float; Right : Integer) return Integer;
function "*" (Left : Float; Right : Integer) return Float;
```

This can lead to context-dependent behavior and silent truncation.

Example risk:

```ada
X : Integer := 1.9 * 2;
```

Depending on overload resolution, this may convert `1.9` to `Integer` before multiplication.

Recommendation:
- remove these overloads,
- keep numeric conversions explicit.

Use:

```ada
Float(I) * X
```

instead of global mixed arithmetic operators.

Checklist:
- [ ] Remove integer-returning mixed arithmetic overloads.
- [ ] Consider removing all mixed arithmetic overloads.
- [ ] Update call sites to use explicit conversions.

---

## 9. Project file and build modes

Current project file is minimal:

```ada
project Gusjo is
   for Source_Dirs use ("./", "ai", "math", "ds", "io", "data", "usage_examples");
   for Object_Dir  use "obj";
end Gusjo;
```

Recommended build-mode project file:

```ada
project Gusjo is
   type Build_Type is ("debug", "release");
   Build : Build_Type := external ("BUILD", "debug");

   for Source_Dirs use ("./", "ai", "math", "ds", "io", "data", "usage_examples");
   for Object_Dir use "obj/" & Build;
   for Create_Missing_Dirs use "True";

   package Compiler is
      case Build is
         when "debug" =>
            for Default_Switches ("Ada") use
              ("-g", "-O0", "-gnata", "-gnatwa");

         when "release" =>
            for Default_Switches ("Ada") use
              ("-O3", "-march=native", "-gnatn", "-gnatwa");
      end case;
   end Compiler;
end Gusjo;
```

Build examples:

```bash
gprbuild -P gusjo.gpr -XBUILD=debug usage_examples/iris_nn.adb
gprbuild -P gusjo.gpr -XBUILD=release usage_examples/iris_nn.adb
```

Checklist:
- [ ] Add debug/release build modes.
- [ ] Enable warnings in both modes.
- [ ] Do not enable `-gnatp` by default.
- [ ] Consider switching from `gnatmake` to `gprbuild`.

---

## 10. README updates

The README should include:
- project purpose,
- package overview,
- build instructions,
- optimized build command,
- benchmark results,
- memory ownership warning,
- examples,
- roadmap link to this `TODO.md`.

Suggested README structure:

```markdown
# Gusjo

Gusjo is an Ada learning and experimentation library containing data structures, linear algebra, dataframe utilities, and a small neural-network module.

## Features

- Matrix and vector operations
- Basic neural-network layers and training
- CSV loading and dataframe utilities
- Generic array-list-backed columns
- Example Iris classifier

## Build

...

## Performance

...

## Development status

This project is exploratory. The current main focus is correctness, memory ownership, and tests.
```

Checklist:
- [ ] Update build command to use `usage_examples/iris_nn.adb`.
- [ ] Update run command to `./obj/iris_nn`.
- [ ] Add benchmark table.
- [ ] Add note about current manual memory management.
- [ ] Link to `TODO.md`.

---

## 11. Recommended tests

Create a test folder:

```text
tests/
   test_linalg.adb
   test_ai.adb
   test_dataframe.adb
   test_nn.adb
```

### Linear algebra tests

- [ ] `Zeros` returns all zeros.
- [ ] `Ones` returns all ones.
- [ ] `Identity_Matrix` has ones on diagonal and zeros elsewhere.
- [ ] Matrix multiplication works for known examples.
- [ ] Transpose works for non-square matrix.
- [ ] Addition/subtraction dimension mismatch raises.
- [ ] `Argmax` returns expected index.
- [ ] `Softmax_Stable` column sums are approximately `1.0`.
- [ ] `CrossEntropy_OneHot` returns expected value.

### AI utility tests

- [ ] `Accuracy` perfect case.
- [ ] `Accuracy` partial case.
- [ ] `Accuracy` length mismatch.
- [ ] `Confusion_Matrix` perfect case.
- [ ] `Confusion_Matrix` with unseen predicted/actual class.
- [ ] Sigmoid derivative from `Z`.
- [ ] Sigmoid derivative from `A`.

### Dataframe tests

- [ ] Load simple CSV.
- [ ] Load numeric/string mixed CSV.
- [ ] Invalid file path raises `CSV_Error`.
- [ ] Feature matrix shape is correct.
- [ ] Response label mapping is deterministic.
- [ ] Seeded split is reproducible.

### Neural-network tests

- [ ] Model with no layers raises on forward.
- [ ] Dense layer output shape is correct.
- [ ] One training step changes weights.
- [ ] Batch forward output shape is correct.
- [ ] Save/load roundtrip preserves predictions.
- [ ] Unsupported loss/activation combination raises.

---

## 12. Suggested implementation order

### Phase 1 – correctness

- [ ] Fix `Identity_Matrix`.
- [ ] Fix `Confusion_Matrix`.
- [ ] Fix `Accuracy`.
- [ ] Fix sigmoid derivative from activation.
- [ ] Fix gradient clipping division.
- [ ] Add guards in `Backward_Batch`.

### Phase 2 – memory hygiene

- [ ] Fix `Free_One_Layer`.
- [ ] Remove or delete unused `Z_M`.
- [ ] Rewrite nested matrix expressions with named temporaries.
- [ ] Delete temporary vectors in `Feature_Matrix`.
- [ ] Add dataframe/list cleanup procedures.

### Phase 3 – reproducibility

- [ ] Add seedable train/test split.
- [ ] Add seedable random initialization.
- [ ] Update Iris example to accept/use fixed seed.
- [ ] Add benchmark mode without printing.

### Phase 4 – tests

- [ ] Add simple custom test runner.
- [ ] Add linear algebra tests.
- [ ] Add dataframe tests.
- [ ] Add neural-network tests.
- [ ] Run tests in debug and release modes.

### Phase 5 – performance

- [ ] Add output-buffer matrix operations.
- [ ] Reduce allocations inside `Train_Batch`.
- [ ] Benchmark matrix multiplication.
- [ ] Consider flat matrix storage.
- [ ] Consider BLAS backend later.

### Phase 6 – API polish

- [ ] Remove mixed `Integer`/`Float` overloads.
- [ ] Standardize index/count types.
- [ ] Improve README.
- [ ] Document ownership rules.
- [ ] Add examples for common workflows.

---

## 13. Immediate next actions

The next concrete coding session should probably do these in order:

1. Fix `Identity_Matrix`.
2. Fix `Free_One_Layer`.
3. Fix `Confusion_Matrix`.
4. Fix sigmoid derivative from activation.
5. Add `--warmup 5` to benchmark script.
6. Add a simple test example for `Identity_Matrix`, `Accuracy`, and `Confusion_Matrix`.

Example benchmark command:

```bash
hyperfine --warmup 5 './obj/iris_nn'
```

Example safer cleanup in shell scripts:

```bash
rm -f obj/*
```

---

## 14. General design principle going forward

For this project, the key distinction is:

```text
Convenient mathematical notation:
   C := A * B + D;

Manual ownership reality:
   A * B allocates memory.
   A * B + D allocates more memory.
   Those intermediate matrices must be freed somehow.
```

Until the matrix type becomes controlled, limited, or otherwise automatically managed, prefer explicit temporaries in nontrivial code:

```ada
declare
   AB : Matrix := A * B;
   C  : Matrix := AB + D;
begin
   Delete(AB);
   return C;
end;
```

For hot training loops, prefer output-buffer procedures instead of allocating expressions.

---

## 15. Long-term target architecture

A mature version of this library could look like:

```text
Gusjo
├── Gusjo.Math
│   ├── Matrix controlled/limited owning type
│   ├── Vector types
│   ├── BLAS-like kernels
│   └── numerical utilities
├── Gusjo.Data
│   ├── DataFrame
│   ├── CSV reader
│   ├── typed columns
│   └── train/test splitting
├── Gusjo.Ai
│   ├── activations
│   ├── losses
│   ├── metrics
│   └── neural-network models
├── Gusjo.Ds
│   └── generic containers
└── usage_examples
    ├── iris_nn.adb
    └── benchmark_nn.adb
```

The strongest next architectural decision is whether `Matrix` should remain a raw access type or become a safer owning abstraction.

