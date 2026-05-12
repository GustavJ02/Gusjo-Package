with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Gusjo.Math.Linalg; use Gusjo.Math.Linalg;

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

   function Accuracy(Predicted, Actual : Indices_Array) return Float is
      Correct : Natural := 0;
   begin
      for I in Predicted'Range loop
         if Predicted(I) = Actual(I) then
            Correct := Correct + 1;
         end if;
      end loop;

      return Float(Correct) / Float(Predicted'Length);
   end Accuracy;

   function Confusion_Matrix(Predicted, Actual : Indices_Array) return Matrix is
   begin
      if Predicted'Length /= Actual'Length then
         raise Constraint_Error with "Predicted and Actual must have same length";
      end if;

      if Predicted'Length = 0 then
         return Zeros(1, 1);
      end if;

      declare
         Max_Labels : constant Positive := Predicted'Length + Actual'Length;

         Unique_Labels : Indices_Array(1 .. Max_Labels) := (others => 1);
         Count         : Natural := 0;

         procedure Add_Label(Label : Positive) is
         begin
            for J in 1 .. Count loop
               if Unique_Labels(J) = Label then
                  return;
               end if;
            end loop;

            Count := Count + 1;
            Unique_Labels(Count) := Label;
         end Add_Label;

         function Find_Index(L : Positive) return Positive is
         begin
            for K in 1 .. Count loop
               if Unique_Labels(K) = L then
                  return K;
               end if;
            end loop;

            raise Constraint_Error with "Label not found in Unique_Labels";
         end Find_Index;

      begin
         for I in Predicted'Range loop
            Add_Label(Predicted(I));
         end loop;

         for I in Actual'Range loop
            Add_Label(Actual(I));
         end loop;

         declare
            type Temp_Matrix is array (Positive range <>, Positive range <>) of Float;

            Temp : Temp_Matrix(1 .. Count, 1 .. Count) :=
            (others => (others => 0.0));

         begin
            for Offset in 0 .. Predicted'Length - 1 loop
               declare
                  P_Label : constant Positive :=
                  Predicted(Predicted'First + Offset);

                  A_Label : constant Positive :=
                  Actual(Actual'First + Offset);

                  P_Idx : constant Positive := Find_Index(P_Label);
                  A_Idx : constant Positive := Find_Index(A_Label);
               begin
                  -- sklearn-style: rows = actual, columns = predicted
                  Temp(A_Idx, P_Idx) := Temp(A_Idx, P_Idx) + 1.0;

                  -- Your original orientation was:
                  -- Temp(P_Idx, A_Idx) := Temp(P_Idx, A_Idx) + 1.0;
               end;
            end loop;

            declare
               CVs : Column_Vector_Array(1 .. Count);
            begin
               for J in 1 .. Count loop
                  declare
                     Values : Float_Array(1 .. Count);
                  begin
                     for I in 1 .. Count loop
                        Values(I) := Temp(I, J);
                     end loop;

                     CVs(J) := Column_Vector_From_Array(Values);
                  end;
               end loop;

               return HStack_Columns(CVs);
            end;
         end;
      end;
   end Confusion_Matrix;

   end Gusjo.Ai;
