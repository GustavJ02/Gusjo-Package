with Ada.Text_IO;              use Ada.Text_IO;
with Ada.Command_Line;         use Ada.Command_Line;
with Ada.Environment_Variables;
with Ada.Calendar;             use Ada.Calendar;

with Gusjo.Math;               use Gusjo.Math;
with Gusjo.Math.Linalg;        use Gusjo.Math.Linalg;

-- matmul_bench --size N --device cpu|gpu [--runs R]
--
-- Multiplies two random N×N matrices R times and prints the mean wall-clock
-- time in milliseconds to stdout.  Exit code 1 on bad arguments.
--
-- Device routing:
--   cpu  : sets GUSJO_MATMUL_USE_CUDA=false  (forces CPU path)
--   gpu  : sets GUSJO_MATMUL_FORCE_CUDA=true (forces GPU path regardless of threshold)

procedure Matmul_Bench is

   procedure Usage is
   begin
      Put_Line ("Usage: matmul_bench --size N --device cpu|gpu [--runs R]");
      Put_Line ("  N      positive integer matrix dimension (N x N)");
      Put_Line ("  device cpu or gpu");
      Put_Line ("  R      number of multiplications to average (default 5)");
   end Usage;

   Size   : Positive := 1;
   Runs   : Positive := 5;
   Device : String (1 .. 3) := "cpu";
   Got_Size, Got_Device : Boolean := False;

   I : Positive := 1;
begin
   -- Parse arguments
   while I <= Argument_Count loop
      declare
         Arg : constant String := Argument (I);
      begin
         if Arg = "--size" and then I < Argument_Count then
            I := I + 1;
            Size := Positive'Value (Argument (I));
            Got_Size := True;
         elsif Arg = "--device" and then I < Argument_Count then
            I := I + 1;
            declare
               D : constant String := Argument (I);
            begin
               if D = "cpu" then
                  Device := "cpu";
                  Got_Device := True;
               elsif D = "gpu" then
                  Device := "gpu";
                  Got_Device := True;
               else
                  Put_Line ("Unknown device '" & D & "' (expected cpu or gpu)");
                  Usage;
                  Set_Exit_Status (Failure);
                  return;
               end if;
            end;
         elsif Arg = "--runs" and then I < Argument_Count then
            I := I + 1;
            Runs := Positive'Value (Argument (I));
         else
            Put_Line ("Unknown argument: " & Arg);
            Usage;
            Set_Exit_Status (Failure);
            return;
         end if;
      end;
      I := I + 1;
   end loop;

   if not Got_Size or not Got_Device then
      Usage;
      Set_Exit_Status (Failure);
      return;
   end if;

   -- Route to CPU or GPU
   if Device = "cpu" then
      Ada.Environment_Variables.Set ("GUSJO_MATMUL_USE_CUDA", "false");
   else
      -- Force GPU even below the 256x256 threshold
      Ada.Environment_Variables.Set ("GUSJO_MATMUL_FORCE_CUDA", "true");
   end if;

   -- Allocate and fill matrices once; reuse across runs.
   -- Run 1 is always a warm-up (not counted in the average) when Runs > 1.
   declare
      A        : Matrix  := Zeros (Size, Size);
      B        : Matrix  := Zeros (Size, Size);
      Timed    : Natural := 0;
      Total_Ms : Float   := 0.0;
   begin
      Fill_Random_Uniform (A, -1.0, 1.0);
      Fill_Random_Uniform (B, -1.0, 1.0);

      for R in 1 .. Runs loop
         declare
            T0 : constant Time := Clock;
            C  : Matrix        := A * B;
            T1 : constant Time := Clock;
         begin
            -- Skip run 1 as warm-up when there is more than one run
            if R > 1 or Runs = 1 then
               Total_Ms := Total_Ms + Float (T1 - T0) * 1_000.0;
               Timed    := Timed + 1;
            end if;
            Delete (C);
         end;
      end loop;

      Delete (A);
      Delete (B);

      -- Single number on stdout — easy to parse from shell / hyperfine JSON
      Put_Line (Float'Image (Total_Ms / Float (Timed)));
   end;
end Matmul_Bench;
