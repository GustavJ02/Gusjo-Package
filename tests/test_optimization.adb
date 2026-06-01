with Ada.Text_IO;             use Ada.Text_IO;
with Ada.Strings;             use Ada.Strings;
with Ada.Strings.Fixed;
with Gusjo.Math;              use Gusjo.Math;
with Gusjo.Math.Linalg;       use Gusjo.Math.Linalg;
with Gusjo.Math.Optimization; use Gusjo.Math.Optimization;

procedure Test_Optimization is

   function Img (F : Float) return String is
   begin
      return Ada.Strings.Fixed.Trim (Float'Image (F), Both);
   end Img;

   -- ---- Test (a): minimize f(x) = (x - 3)^2 ----
   -- gradient: 2*(x - 3)

   function Loss_A (Params : Matrix) return Float is
      X : constant Float := Element_at (Params, 1, 1);
   begin
      return (X - 3.0) ** 2;
   end Loss_A;

   function Grad_A (Params : Matrix) return Matrix is
      X : constant Float  := Element_at (Params, 1, 1);
      G : constant Matrix := Zeros (1, 1);
   begin
      Element_at (G, 1, 1, 2.0 * (X - 3.0));
      return G;
   end Grad_A;

   -- ---- Test (b): linear regression y = w*x, points (1,2),(2,4),(3,6) ----
   -- MSE gradient: (2/N) * sum((w*x_i - y_i) * x_i)

   function Loss_B (Params : Matrix) return Float is
      W  : constant Float := Element_at (Params, 1, 1);
      E1 : constant Float := W * 1.0 - 2.0;
      E2 : constant Float := W * 2.0 - 4.0;
      E3 : constant Float := W * 3.0 - 6.0;
   begin
      return (E1 * E1 + E2 * E2 + E3 * E3) / 3.0;
   end Loss_B;

   function Grad_B (Params : Matrix) return Matrix is
      W    : constant Float  := Element_at (Params, 1, 1);
      G    : constant Matrix := Zeros (1, 1);
      Gval : constant Float  :=
        (2.0 / 3.0) * ((W * 1.0 - 2.0) * 1.0
                     + (W * 2.0 - 4.0) * 2.0
                     + (W * 3.0 - 6.0) * 3.0);
   begin
      Element_at (G, 1, 1, Gval);
      return G;
   end Grad_B;

begin
   -- ----------------------------------------------------------------
   Put_Line ("=== Test (a): minimize (x-3)^2 with Adam ===");
   declare
      Config_A : constant Optimizer_Config :=
        (Method             => Adam,
         Learning_Rate      => 0.1,
         Beta_1             => 0.9,
         Beta_2             => 0.999,
         Epsilon            => 1.0e-8,
         Weight_Decay       => 0.0,
         Clip_Threshold     => 0.0,
         Max_Epochs         => 1000,
         Gradient_Tolerance => 1.0e-4,
         Loss_Tolerance     => 0.0,
         Schedule           =>
           (Kind         => Constant_LR,
            Warmup_Steps => 0,
            Min_LR       => 0.0,
            Total_Steps  => 0));
      Params_A : Matrix := Zeros (1, 1);
      State_A  : Optimizer_State (Kind => Adam);
      Result_A : Optimization_Result;
   begin
      Result_A := Optimize
        (Params_A,
         Loss_A'Unrestricted_Access,
         Grad_A'Unrestricted_Access,
         Config_A, State_A);
      declare
         X_Final : constant Float := Element_at (Params_A, 1, 1);
      begin
         Put_Line ("  Epochs:     " & Natural'Image (Result_A.Epochs_Run));
         Put_Line ("  Final x:    " & Img (X_Final));
         Put_Line ("  Final loss: " & Img (Result_A.Final_Loss));
         if abs (X_Final - 3.0) < 0.01 then
            Put_Line ("  Converged to x=3: PASS");
         else
            Put_Line ("  Converged to x=3: FAIL");
         end if;
      end;
   end;

   -- ----------------------------------------------------------------
   New_Line;
   Put_Line ("=== Test (b): linear regression y=w*x with GD ===");
   declare
      Config_B : constant Optimizer_Config :=
        (Method             => Gradient_Descent,
         Learning_Rate      => 0.05,
         Beta_1             => 0.9,
         Beta_2             => 0.999,
         Epsilon            => 1.0e-8,
         Weight_Decay       => 0.0,
         Clip_Threshold     => 0.0,
         Max_Epochs         => 200,
         Gradient_Tolerance => 1.0e-6,
         Loss_Tolerance     => 0.0,
         Schedule           =>
           (Kind         => Constant_LR,
            Warmup_Steps => 0,
            Min_LR       => 0.0,
            Total_Steps  => 0));
      Params_B : Matrix := Zeros (1, 1);
      State_B  : Optimizer_State (Kind => Gradient_Descent);
      Result_B : Optimization_Result;
   begin
      Result_B := Optimize
        (Params_B,
         Loss_B'Unrestricted_Access,
         Grad_B'Unrestricted_Access,
         Config_B, State_B);
      declare
         W_Final : constant Float := Element_at (Params_B, 1, 1);
      begin
         Put_Line ("  Epochs:     " & Natural'Image (Result_B.Epochs_Run));
         Put_Line ("  Final w:    " & Img (W_Final));
         Put_Line ("  Final loss: " & Img (Result_B.Final_Loss));
         if abs (W_Final - 2.0) < 0.001 then
            Put_Line ("  Converged to w=2: PASS");
         else
            Put_Line ("  Converged to w=2: FAIL");
         end if;
      end;
   end;

   -- ----------------------------------------------------------------
   New_Line;
   Put_Line ("=== Test (c): Warmup_Cosine LR schedule ===");
   declare
      Base_LR_C : constant Float   := 0.001;
      Min_LR_C  : constant Float   := 0.0;
      Warmup_C  : constant Natural := 100;
      Total_C   : constant Natural := 1000;
      Tol       : constant Float   := 1.0e-6;

      Config_C : constant Optimizer_Config :=
        (Method             => AdamW,
         Learning_Rate      => Base_LR_C,
         Beta_1             => 0.9,
         Beta_2             => 0.999,
         Epsilon            => 1.0e-8,
         Weight_Decay       => 0.1,
         Clip_Threshold     => 1.0,
         Max_Epochs         => 1000,
         Gradient_Tolerance => 0.0,
         Loss_Tolerance     => 0.0,
         Schedule           =>
           (Kind         => Warmup_Cosine,
            Warmup_Steps => Warmup_C,
            Min_LR       => Min_LR_C,
            Total_Steps  => Total_C));

      LR_At_0      : constant Float := Current_LR (Config_C, 0);
      LR_At_Warmup : constant Float := Current_LR (Config_C, Warmup_C);
      LR_At_Total  : constant Float := Current_LR (Config_C, Total_C);

      Warmup_Mono : Boolean := True;
      Decay_Mono  : Boolean := True;
      Prev_LR     : Float;
   begin
      if abs (LR_At_0) < Tol then
         Put_Line ("  LR at step 0 = 0:      PASS");
      else
         Put_Line ("  LR at step 0 = 0:      FAIL (" & Img (LR_At_0) & ")");
      end if;

      if abs (LR_At_Warmup - Base_LR_C) < Tol then
         Put_Line ("  LR at warmup end = LR: PASS");
      else
         Put_Line ("  LR at warmup end = LR: FAIL (" & Img (LR_At_Warmup) & ")");
      end if;

      if abs (LR_At_Total - Min_LR_C) < Tol then
         Put_Line ("  LR at total steps = 0: PASS");
      else
         Put_Line ("  LR at total steps = 0: FAIL (" & Img (LR_At_Total) & ")");
      end if;

      Prev_LR := LR_At_0;
      for Step in 1 .. Warmup_C loop
         declare
            LR : constant Float := Current_LR (Config_C, Step);
         begin
            if LR < Prev_LR then
               Warmup_Mono := False;
            end if;
            Prev_LR := LR;
         end;
      end loop;
      if Warmup_Mono then
         Put_Line ("  Warmup monotone:       PASS");
      else
         Put_Line ("  Warmup monotone:       FAIL");
      end if;

      Prev_LR := LR_At_Warmup;
      for Step in Warmup_C + 1 .. Total_C loop
         declare
            LR : constant Float := Current_LR (Config_C, Step);
         begin
            if LR > Prev_LR then
               Decay_Mono := False;
            end if;
            Prev_LR := LR;
         end;
      end loop;
      if Decay_Mono then
         Put_Line ("  Cosine decay monotone: PASS");
      else
         Put_Line ("  Cosine decay monotone: FAIL");
      end if;
   end;

end Test_Optimization;
