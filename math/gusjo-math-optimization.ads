package Gusjo.Math.Optimization is

   type Optimizer_Kind is (
      Gradient_Descent,
      Newton_Method,
      BFGS);

   type Stop_Reason is (
      Max_Epochs_Reached,
      Gradient_Tolerance_Reached,
      Loss_Tolerance_Reached);

   type Optimizer_Config is record
      Method : Optimizer_Kind := Gradient_Descent;
      Learning_Rate : Float := 0.01;
      Max_Epochs : Positive := 1000;
      Gradient_Tolerance : Float := 0.0;
      Loss_Tolerance : Float := 0.0;
      Clip_Threshold : Float := 0.0;
   end record;

   type Optimization_Result is record
      Epochs_Run : Natural := 0;
      Final_Loss : Float := 0.0;
      Final_Gradient_Norm : Float := 0.0;
      Reason : Stop_Reason := Max_Epochs_Reached;
   end record;

end Gusjo.Math.Optimization;
