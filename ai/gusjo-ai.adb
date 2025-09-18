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

   function To_Activation_Kind(Item : in String) return Activation_Kind is
   begin
      if Item = "sigmoid" then
         return Sigmoid;
      elsif Item = "relu" then
         return ReLU;
      elsif Item = "softmax" then
         return Softmax;
      else
         raise Constraint_Error with "Unable to read """ & Item & """ as Activation_Kind.";
      end if;
   end To_Activation_Kind;

   function To_Loss_Kind(Item : in String) return Loss_Kind is
   begin
      if Item = "mse" then 
         return MSE;
      elsif Item = "crossentropy" then
         return CrossEntropy;
      else
         raise Constraint_Error with "Unable to read """ & Item & """ as Loss_Kind.";
      end if;
   end To_Loss_Kind;

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
   
   function Sigmoid_Derivative(Z : in Float) return Float is
      A : constant Float := 1.0 / (1.0 + Exp(-Z));
   begin
      return A * (1.0 - A);
   end Sigmoid_Derivative;
   
   function Relu_Derivative(Z : in Float) return Float is
   begin
      if Z > 0.0 then
         return 1.0;
      else
         return 0.0;
      end if;
   end Relu_Derivative;
   
end Gusjo.Ai;
