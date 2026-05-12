with Gusjo.Math;              use Gusjo.Math;
with Gusjo.Math.Linalg;       use Gusjo.Math.Linalg;

package Gusjo.Ai is
   -- Activations
   type Activation_Kind is (Sigmoid, ReLU, Softmax);

   -- Losses
   type Loss_Kind is (MSE, CrossEntropy);

   
   function Sigmoid(Z : in Float) return Float;
   
   function ReLU(Z : in Float) return Float;

   function Sigmoid_Derivative (Z : in Float) return Float;
   
   function Relu_Derivative (Z : in Float) return Float;

   -- Utilities (optional, handy for logs)
   function To_String(A : Activation_Kind) return String;
   function To_String(L : Loss_Kind)       return String;

   function To_Activation_Kind(Item : in String) return Activation_Kind;
   function To_Loss_Kind(Item : in String) return Loss_Kind;

   function Accuracy(Predicted, Actual : Indices_Array) return Float;

   function Confusion_Matrix(Predicted, Actual : Indices_Array) return Matrix;

end Gusjo.Ai;
