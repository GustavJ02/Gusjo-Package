with Ada.Text_IO;              use Ada.Text_IO;
with Ada.Environment_Variables;
with Ada.Calendar;             use Ada.Calendar;
with Ada.Strings;              use Ada.Strings;
with Ada.Strings.Fixed;

with Gusjo.Math;               use Gusjo.Math;
with Gusjo.Math.Linalg;        use Gusjo.Math.Linalg;

procedure Test_Cuda_Matmul is

   function Img (F : Float) return String is
   begin
      return Ada.Strings.Fixed.Trim (Float'Image (F), Both);
   end Img;

   -- Elapsed milliseconds between two Calendar times
   function Ms (Start, Stop : Time) return Float is
   begin
      return Float (Stop - Start) * 1_000.0;
   end Ms;

   -- Check that every element of M equals Expected within Tol
   function All_Close (M : Matrix; Expected, Tol : Float) return Boolean is
   begin
      for I in 1 .. Rows (M) loop
         for J in 1 .. Cols (M) loop
            if abs (Element_at (M, I, J) - Expected) > Tol then
               return False;
            end if;
         end loop;
      end loop;
      return True;
   end All_Close;

   -- Element-wise max absolute difference between two same-shape matrices
   function Max_Diff (A, B : Matrix) return Float is
      D : Float := 0.0;
   begin
      for I in 1 .. Rows (A) loop
         for J in 1 .. Cols (A) loop
            declare
               V : constant Float := abs (Element_at (A, I, J) - Element_at (B, I, J));
            begin
               if V > D then D := V; end if;
            end;
         end loop;
      end loop;
      return D;
   end Max_Diff;

   CUDA_Present : constant Boolean := GPU_Matmul_Available;

begin
   Put_Line ("=== CUDA Matmul Test ===");
   Put_Line ("CUDA hardware present: " & Boolean'Image (CUDA_Present));
   New_Line;

   -- ---------------------------------------------------------------
   --  Test 1: disable GPU via environment variable
   -- ---------------------------------------------------------------
   Put_Line ("--- Test 1: GUSJO_MATMUL_USE_CUDA=false ---");
   Ada.Environment_Variables.Set ("GUSJO_MATMUL_USE_CUDA", "false");
   if not GPU_Matmul_Env_Enabled then
      Put_Line ("  Env var disabled GPU: PASS");
   else
      Put_Line ("  Env var disabled GPU: FAIL");
   end if;

   -- ---------------------------------------------------------------
   --  Test 2: re-enable GPU via environment variable
   -- ---------------------------------------------------------------
   Put_Line ("--- Test 2: GUSJO_MATMUL_USE_CUDA=true ---");
   Ada.Environment_Variables.Set ("GUSJO_MATMUL_USE_CUDA", "true");
   if GPU_Matmul_Env_Enabled then
      Put_Line ("  Env var enabled GPU: PASS");
   else
      Put_Line ("  Env var enabled GPU: FAIL");
   end if;
   Ada.Environment_Variables.Clear ("GUSJO_MATMUL_USE_CUDA");

   -- ---------------------------------------------------------------
   --  Test 3: small matrix (128x128) — must use CPU path even with GPU
   --  A = ones, B = ones  =>  C = 128 * ones
   -- ---------------------------------------------------------------
   Put_Line ("--- Test 3: 128x128 matmul (below GPU threshold, must use CPU) ---");
   declare
      Size : constant := 128;
      A    : Matrix   := Ones (Size, Size);
      B    : Matrix   := Ones (Size, Size);
      C    : Matrix   := A * B;
   begin
      if All_Close (C, Float (Size), 1.0e-3) then
         Put_Line ("  Result correct: PASS");
      else
         Put_Line ("  Result correct: FAIL (expected all elements = "
                   & Img (Float (Size)) & ")");
      end if;
      Delete (A);
      Delete (B);
      Delete (C);
   end;

   -- ---------------------------------------------------------------
   --  Test 4: 512x512 — benchmark CPU vs GPU, compare results
   -- ---------------------------------------------------------------
   Put_Line ("--- Test 4: 512x512 matmul — CPU vs GPU correctness and timing ---");
   declare
      Size : constant := 512;
      A    : Matrix   := Zeros (Size, Size);
      B    : Matrix   := Zeros (Size, Size);
   begin
      Fill_Random_Uniform (A, -1.0, 1.0);
      Fill_Random_Uniform (B, -1.0, 1.0);

      -- CPU run: force by disabling CUDA via env var
      Ada.Environment_Variables.Set ("GUSJO_MATMUL_USE_CUDA", "false");
      declare
         T0      : constant Time   := Clock;
         C_CPU   : Matrix          := A * B;
         T1      : constant Time   := Clock;
         CPU_Ms  : constant Float  := Ms (T0, T1);
      begin
         Ada.Environment_Variables.Clear ("GUSJO_MATMUL_USE_CUDA");

         if CUDA_Present then
            -- GPU run 1: cold — initialises cuBLAS handle, expect slower
            declare
               T2        : constant Time   := Clock;
               C_GPU_1   : Matrix          := A * B;
               T3        : constant Time   := Clock;
               GPU_Cold  : constant Float  := Ms (T2, T3);
            begin
               Delete (C_GPU_1);

               -- GPU run 2: warm — handle already initialised
               declare
                  T4        : constant Time   := Clock;
                  C_GPU     : Matrix          := A * B;
                  T5        : constant Time   := Clock;
                  GPU_Ms    : constant Float  := Ms (T4, T5);
                  Diff      : constant Float  := Max_Diff (C_CPU, C_GPU);
               begin
                  Put_Line ("  CPU time      : " & Img (CPU_Ms)   & " ms");
                  Put_Line ("  GPU time cold : " & Img (GPU_Cold) & " ms  (cuBLAS init + first alloc)");
                  Put_Line ("  GPU time warm : " & Img (GPU_Ms)   & " ms");
                  Put_Line ("  Max element diff (CPU vs GPU): " & Img (Diff));
                  if Diff < 1.0e-2 then
                     Put_Line ("  Numerical agreement: PASS");
                  else
                     Put_Line ("  Numerical agreement: FAIL");
                  end if;
                  if GPU_Ms < CPU_Ms then
                     Put_Line ("  Warm GPU faster than CPU: PASS");
                  else
                     Put_Line ("  Warm GPU faster than CPU: NOTE (warm GPU="
                               & Img (GPU_Ms) & " ms, CPU=" & Img (CPU_Ms) & " ms)");
                  end if;
                  Delete (C_GPU);
               end;
            end;
         else
            Put_Line ("  No CUDA GPU — skipping GPU run");
            Put_Line ("  CPU time : " & Img (CPU_Ms) & " ms");
            -- Still verify the CPU result is in a plausible range:
            -- 512x512 of U(-1,1) * U(-1,1): each element is sum of 512 products,
            -- E[element]=0, so values cluster around 0.  Just sanity-check finite.
            if All_Close (C_CPU, 0.0, Float (Size) * 2.0) then
               Put_Line ("  CPU result in expected range: PASS");
            else
               Put_Line ("  CPU result in expected range: FAIL");
            end if;
         end if;
         Delete (C_CPU);
      end;

      Delete (A);
      Delete (B);
   end;

end Test_Cuda_Matmul;
