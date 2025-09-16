with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;

package body Gusjo.Ai is
   function To_String (A : Activation_Kind) return String is
   begin
      case A is
         when Sigmoid => return "sigmoid";
         when ReLU    => return "relu";
         when Softmax => return "softmax";
      end case;
   end;

   function To_String (L : Loss_Kind) return String is
   begin
      case L is
         when MSE          => return "mse";
         when CrossEntropy => return "crossentropy";
      end case;
   end;

   function Sigmoid(Z : in Float) return Float is
   begin
      return 1.0 / (1.0 + Exp(-Z));
   end Sigmoid;

   function ReLU(Z : in Float) return Float is
   begin
      if Z > 0 then
         return Z;
      else
         return 0.0;
      end if;
   end ReLU;
   
   function Sigmoid_Derivative (Z : in Float) return Float is
   begin
      return Z * (1.0 - Z);
   end Sigmoid_Derivative;
   
   function Relu_Derivative (Z : in Float) return Float is
   begin
      if Z > 0.0 then
         return 1.0;
      else
         return 0.0;
      end if;
   end Relu_Derivative;
end Gusjo.Ai;
