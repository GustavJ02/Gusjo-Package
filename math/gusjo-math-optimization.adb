with Ada.Numerics.Elementary_Functions;
with Gusjo.Math.Linalg;

package body Gusjo.Math.Optimization is

   use Ada.Numerics.Elementary_Functions;
   use Gusjo.Math.Linalg;

   function Current_LR
     (Config : Optimizer_Config;
      Step   : Natural) return Float
   is
      Base_LR : constant Float      := Config.Learning_Rate;
      S       : constant LR_Schedule := Config.Schedule;
   begin
      case S.Kind is
         when Constant_LR =>
            return Base_LR;

         when Linear_Warmup =>
            if Step < S.Warmup_Steps then
               return Base_LR * Float (Step) / Float (S.Warmup_Steps);
            else
               return Base_LR;
            end if;

         when Cosine_Decay =>
            if S.Total_Steps = 0 or Step >= S.Total_Steps then
               return S.Min_LR;
            end if;
            declare
               Progress : constant Float :=
                 Float (Step) / Float (S.Total_Steps);
               Cosine   : constant Float :=
                 0.5 * (1.0 + Cos (Ada.Numerics.Pi * Progress));
            begin
               return S.Min_LR + (Base_LR - S.Min_LR) * Cosine;
            end;

         when Warmup_Cosine =>
            if Step < S.Warmup_Steps then
               return Base_LR * Float (Step) / Float (S.Warmup_Steps);
            else
               declare
                  Progress : constant Float :=
                    Float (Step - S.Warmup_Steps) /
                    Float (S.Total_Steps - S.Warmup_Steps);
                  Cosine   : constant Float :=
                    0.5 * (1.0 + Cos (Ada.Numerics.Pi * Progress));
               begin
                  return S.Min_LR + (Base_LR - S.Min_LR) * Cosine;
               end;
            end if;
      end case;
   end Current_LR;

   function Clip_Gradients
     (Gradients : in out Matrix;
      Threshold : in     Float) return Float
   is
      Norm : constant Float := L2_Norm (Gradients);
   begin
      if Norm > Threshold then
         Scale_In_Place (Gradients, Threshold / Norm);
      end if;
      return Norm;
   end Clip_Gradients;

   procedure Adam_Update
     (Params       : in out Matrix;
      Gradients    : in     Matrix;
      State        : in out Adam_State;
      Config       : in     Optimizer_Config;
      Current_Step : in     Natural)
   is
      LR   : constant Float    := Current_LR (Config, Current_Step);
      B1   : constant Float    := Config.Beta_1;
      B2   : constant Float    := Config.Beta_2;
      Eps  : constant Float    := Config.Epsilon;
      Rows : constant Positive := Gusjo.Math.Linalg.Rows (Params);
      Cols : constant Positive := Gusjo.Math.Linalg.Cols (Params);
   begin
      if not State.Ready then
         State.M     := Gusjo.Math.Linalg.Zeros (Rows, Cols);
         State.V     := Gusjo.Math.Linalg.Zeros (Rows, Cols);
         State.Ready := True;
      end if;

      State.Step := State.Step + 1;

      declare
         BC1 : constant Float := 1.0 - B1 ** State.Step;
         BC2 : constant Float := 1.0 - B2 ** State.Step;
      begin
         for I in 1 .. Rows loop
            for J in 1 .. Cols loop
               declare
                  G     : constant Float := Element_at (Gradients, I, J);
                  M_IJ  : constant Float :=
                    B1 * Element_at (State.M, I, J) + (1.0 - B1) * G;
                  V_IJ  : constant Float :=
                    B2 * Element_at (State.V, I, J) + (1.0 - B2) * G * G;
                  M_Hat : constant Float := M_IJ / BC1;
                  V_Hat : constant Float := V_IJ / BC2;
               begin
                  Element_at (State.M, I, J, M_IJ);
                  Element_at (State.V, I, J, V_IJ);
                  Element_at (Params, I, J,
                    Element_at (Params, I, J)
                    - LR * M_Hat / (Sqrt (V_Hat) + Eps));
               end;
            end loop;
         end loop;
      end;
   end Adam_Update;

   procedure AdamW_Update
     (Params       : in out Matrix;
      Gradients    : in     Matrix;
      State        : in out Adam_State;
      Config       : in     Optimizer_Config;
      Current_Step : in     Natural)
   is
      LR   : constant Float    := Current_LR (Config, Current_Step);
      B1   : constant Float    := Config.Beta_1;
      B2   : constant Float    := Config.Beta_2;
      Eps  : constant Float    := Config.Epsilon;
      Rows : constant Positive := Gusjo.Math.Linalg.Rows (Params);
      Cols : constant Positive := Gusjo.Math.Linalg.Cols (Params);
   begin
      if not State.Ready then
         State.M     := Gusjo.Math.Linalg.Zeros (Rows, Cols);
         State.V     := Gusjo.Math.Linalg.Zeros (Rows, Cols);
         State.Ready := True;
      end if;

      State.Step := State.Step + 1;

      declare
         BC1 : constant Float := 1.0 - B1 ** State.Step;
         BC2 : constant Float := 1.0 - B2 ** State.Step;
      begin
         for I in 1 .. Rows loop
            for J in 1 .. Cols loop
               declare
                  G     : constant Float := Element_at (Gradients, I, J);
                  M_IJ  : constant Float :=
                    B1 * Element_at (State.M, I, J) + (1.0 - B1) * G;
                  V_IJ  : constant Float :=
                    B2 * Element_at (State.V, I, J) + (1.0 - B2) * G * G;
                  M_Hat : constant Float := M_IJ / BC1;
                  V_Hat : constant Float := V_IJ / BC2;
                  P_IJ  : constant Float := Element_at (Params, I, J);
               begin
                  Element_at (State.M, I, J, M_IJ);
                  Element_at (State.V, I, J, V_IJ);
                  Element_at (Params, I, J,
                    P_IJ
                    - LR * M_Hat / (Sqrt (V_Hat) + Eps)
                    - LR * Config.Weight_Decay * P_IJ);
               end;
            end loop;
         end loop;
      end;
   end AdamW_Update;

   procedure GD_Update
     (Params        : in out Matrix;
      Gradients     : in     Matrix;
      Learning_Rate : in     Float)
   is
      Rows : constant Positive := Gusjo.Math.Linalg.Rows (Params);
      Cols : constant Positive := Gusjo.Math.Linalg.Cols (Params);
   begin
      for I in 1 .. Rows loop
         for J in 1 .. Cols loop
            Element_at (Params, I, J,
              Element_at (Params, I, J)
              - Learning_Rate * Element_at (Gradients, I, J));
         end loop;
      end loop;
   end GD_Update;

   procedure SGD_Momentum_Update
     (Params       : in out Matrix;
      Gradients    : in     Matrix;
      State        : in out SGD_State;
      Config       : in     Optimizer_Config;
      Current_Step : in     Natural)
   is
      LR   : constant Float    := Current_LR (Config, Current_Step);
      B1   : constant Float    := Config.Beta_1;
      Rows : constant Positive := Gusjo.Math.Linalg.Rows (Params);
      Cols : constant Positive := Gusjo.Math.Linalg.Cols (Params);
   begin
      if not State.Ready then
         State.M     := Gusjo.Math.Linalg.Zeros (Rows, Cols);
         State.Ready := True;
      end if;

      State.Step := State.Step + 1;

      for I in 1 .. Rows loop
         for J in 1 .. Cols loop
            declare
               G    : constant Float := Element_at (Gradients, I, J);
               M_IJ : constant Float :=
                 B1 * Element_at (State.M, I, J) + (1.0 - B1) * G;
            begin
               Element_at (State.M, I, J, M_IJ);
               Element_at (Params, I, J,
                 Element_at (Params, I, J) - LR * M_IJ);
            end;
         end loop;
      end loop;
   end SGD_Momentum_Update;

   function Optimize
     (Params            : in out Matrix;
      Compute_Loss      : in     Loss_Function;
      Compute_Gradients : in     Gradient_Function;
      Config            : in     Optimizer_Config;
      State             : in out Optimizer_State) return Optimization_Result
   is
      Result    : Optimization_Result;
      Prev_Loss : Float := Float'Last;
   begin
      for Epoch in 1 .. Config.Max_Epochs loop
         declare
            Loss      : constant Float := Compute_Loss (Params);
            Grads     : Matrix         := Compute_Gradients (Params);
            Grad_Norm : Float;
         begin
            if Config.Clip_Threshold > 0.0 then
               Grad_Norm := Clip_Gradients (Grads, Config.Clip_Threshold);
            else
               Grad_Norm := L2_Norm (Grads);
            end if;

            case Config.Method is
               when Adam =>
                  Adam_Update (Params, Grads, State.Adam, Config, Epoch);
               when AdamW =>
                  AdamW_Update (Params, Grads, State.Adam, Config, Epoch);
               when Gradient_Descent =>
                  GD_Update (Params, Grads, Current_LR (Config, Epoch));
               when SGD_Momentum =>
                  SGD_Momentum_Update (Params, Grads, State.SGD, Config, Epoch);
            end case;

            Result.Epochs_Run          := Epoch;
            Result.Final_Loss          := Loss;
            Result.Final_Gradient_Norm := Grad_Norm;

            Delete (Grads);

            if Config.Gradient_Tolerance > 0.0
              and then Grad_Norm < Config.Gradient_Tolerance
            then
               Result.Reason := Gradient_Tolerance_Reached;
               return Result;
            end if;

            if Config.Loss_Tolerance > 0.0
              and then abs (Loss - Prev_Loss) < Config.Loss_Tolerance
            then
               Result.Reason := Loss_Tolerance_Reached;
               return Result;
            end if;

            Prev_Loss := Loss;
         end;
      end loop;

      Result.Reason := Max_Epochs_Reached;
      return Result;
   end Optimize;

   procedure Optimize_Step
     (Params       : in out Matrix;
      Gradients    : in     Matrix;
      Config       : in     Optimizer_Config;
      State        : in out Optimizer_State;
      Current_Step : in     Natural)
   is
      procedure Apply_Update (G : in Matrix) is
      begin
         case Config.Method is
            when Adam =>
               Adam_Update (Params, G, State.Adam, Config, Current_Step);
            when AdamW =>
               AdamW_Update (Params, G, State.Adam, Config, Current_Step);
            when Gradient_Descent =>
               GD_Update (Params, G, Current_LR (Config, Current_Step));
            when SGD_Momentum =>
               SGD_Momentum_Update (Params, G, State.SGD, Config, Current_Step);
         end case;
      end Apply_Update;
   begin
      if Config.Clip_Threshold > 0.0 then
         declare
            G    : Matrix := Copy (Gradients);
            Norm : Float;
            pragma Unreferenced (Norm);
         begin
            Norm := Clip_Gradients (G, Config.Clip_Threshold);
            Apply_Update (G);
            Delete (G);
         end;
      else
         Apply_Update (Gradients);
      end if;
   end Optimize_Step;

   function Make_State (Kind : Optimizer_Kind) return Optimizer_State is
   begin
      case Kind is
         when Adam =>
            return (Kind => Adam, Adam => (others => <>));
         when AdamW =>
            return (Kind => AdamW, Adam => (others => <>));
         when SGD_Momentum =>
            return (Kind => SGD_Momentum, SGD => (others => <>));
         when Gradient_Descent =>
            return (Kind => Gradient_Descent);
      end case;
   end Make_State;

   procedure Free_State (State : in out Optimizer_State) is
   begin
      case State.Kind is
         when Adam | AdamW =>
            if State.Adam.Ready then
               Delete (State.Adam.M);
               Delete (State.Adam.V);
               State.Adam.Ready := False;
               State.Adam.Step  := 0;
            end if;
         when SGD_Momentum =>
            if State.SGD.Ready then
               Delete (State.SGD.M);
               State.SGD.Ready := False;
               State.SGD.Step  := 0;
            end if;
         when Gradient_Descent =>
            null;
      end case;
   end Free_State;

end Gusjo.Math.Optimization;
