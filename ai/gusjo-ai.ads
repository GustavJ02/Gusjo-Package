package Gusjo.Ai is
   -- Activations
   type Activation_Kind is (Sigmoid, ReLU);

   -- Losses
   type Loss_Kind is (MSE, CrossEntropy);

   -- Utilities (optional, handy for logs)
   function To_String (A : Activation_Kind) return String;
   function To_String (L : Loss_Kind)       return String;
end Gusjo.Ai;
