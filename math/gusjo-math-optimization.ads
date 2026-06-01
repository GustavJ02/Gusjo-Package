with Gusjo.Math;  use Gusjo.Math;
package Gusjo.Math.Optimization is

   -- --------------------------------------------------------
   --  Optimizer kinds
   -- --------------------------------------------------------
   type Optimizer_Kind is (
      Gradient_Descent,
      SGD_Momentum,
      Adam,
      AdamW);

   type Stop_Reason is (
      Max_Epochs_Reached,
      Gradient_Tolerance_Reached,
      Loss_Tolerance_Reached);

   -- --------------------------------------------------------
   --  Learning rate schedule
   -- --------------------------------------------------------
   type LR_Schedule_Kind is (
      Constant_LR,
      Linear_Warmup,
      Cosine_Decay,
      Warmup_Cosine);

   type LR_Schedule is record
      Kind         : LR_Schedule_Kind := Constant_LR;
      Warmup_Steps : Natural          := 0;
      Min_LR       : Float            := 0.0;
      Total_Steps  : Natural          := 0;
   end record;

   -- --------------------------------------------------------
   --  Optimizer configuration
   -- --------------------------------------------------------
   type Optimizer_Config is record
      Method             : Optimizer_Kind := AdamW;
      Learning_Rate      : Float          := 3.0e-4;
      Beta_1             : Float          := 0.9;
      Beta_2             : Float          := 0.999;
      Epsilon            : Float          := 1.0e-8;
      Weight_Decay       : Float          := 0.1;
      Clip_Threshold     : Float          := 1.0;
      Max_Epochs         : Positive       := 1000;
      Gradient_Tolerance : Float          := 0.0;
      Loss_Tolerance     : Float          := 0.0;
      Schedule           : LR_Schedule;
   end record;

   -- --------------------------------------------------------
   --  Optimizer state types
   -- --------------------------------------------------------
   type Adam_State is record
      M     : Matrix;
      V     : Matrix;
      Step  : Natural := 0;
      Ready : Boolean := False;
   end record;

   type SGD_State is record
      M     : Matrix;
      Step  : Natural := 0;
      Ready : Boolean := False;
   end record;

   -- Unified state; Kind discriminant must match Config.Method
   type Optimizer_State (Kind : Optimizer_Kind := AdamW) is record
      case Kind is
         when Adam | AdamW =>
            Adam : Adam_State;
         when SGD_Momentum =>
            SGD  : SGD_State;
         when Gradient_Descent =>
            null;
      end case;
   end record;

   -- --------------------------------------------------------
   --  Optimization result
   -- --------------------------------------------------------
   type Optimization_Result is record
      Epochs_Run          : Natural   := 0;
      Final_Loss          : Float     := 0.0;
      Final_Gradient_Norm : Float     := 0.0;
      Reason              : Stop_Reason := Max_Epochs_Reached;
   end record;

   -- --------------------------------------------------------
   --  Callbacks for general optimization
   -- --------------------------------------------------------
   type Loss_Function     is access function (Params : Matrix) return Float;
   type Gradient_Function is access function (Params : Matrix) return Matrix;

   -- --------------------------------------------------------
   --  Core optimizer operations
   -- --------------------------------------------------------

   -- Compute current learning rate given schedule and step number
   function Current_LR
     (Config : Optimizer_Config;
      Step   : Natural) return Float;

   -- Clip gradient matrix in-place so its L2 norm <= Threshold
   -- Returns the pre-clip norm
   function Clip_Gradients
     (Gradients : in out Matrix;
      Threshold : in     Float) return Float;

   procedure Adam_Update
     (Params       : in out Matrix;
      Gradients    : in     Matrix;
      State        : in out Adam_State;
      Config       : in     Optimizer_Config;
      Current_Step : in     Natural);

   procedure AdamW_Update
     (Params       : in out Matrix;
      Gradients    : in     Matrix;
      State        : in out Adam_State;
      Config       : in     Optimizer_Config;
      Current_Step : in     Natural);

   procedure GD_Update
     (Params        : in out Matrix;
      Gradients     : in     Matrix;
      Learning_Rate : in     Float);

   procedure SGD_Momentum_Update
     (Params       : in out Matrix;
      Gradients    : in     Matrix;
      State        : in out SGD_State;
      Config       : in     Optimizer_Config;
      Current_Step : in     Natural);

   -- General minimize: calls Compute_Loss and Compute_Gradients each epoch
   function Optimize
     (Params            : in out Matrix;
      Compute_Loss      : in     Loss_Function;
      Compute_Gradients : in     Gradient_Function;
      Config            : in     Optimizer_Config;
      State             : in out Optimizer_State) return Optimization_Result;

   -- Hot-path update for GPT training: gradient pre-computed by backprop
   procedure Optimize_Step
     (Params       : in out Matrix;
      Gradients    : in     Matrix;
      Config       : in     Optimizer_Config;
      State        : in out Optimizer_State;
      Current_Step : in     Natural);

   -- Free any heap matrices inside a state (call from layer cleanup)
   procedure Free_State (State : in out Optimizer_State);

   -- Return a fresh zeroed state for the given optimizer kind
   function Make_State (Kind : Optimizer_Kind) return Optimizer_State;

end Gusjo.Math.Optimization;
