with Ada.Text_IO;         use Ada.Text_IO;
with Ada.Float_Text_IO;   use Ada.Float_Text_IO;

with Gusjo.Ai;            use Gusjo.Ai;
with Gusjo.Ai.Nn;         use Gusjo.Ai.Nn;

with Gusjo.Math;          use Gusjo.Math;
with Gusjo.Math.Linalg;   use Gusjo.Math.Linalg;

procedure Nn is
   M : Model;

   -- Inputs (2 features)
   X1 : constant Column_Vector := Column2(0.0, 0.0);
   X2 : constant Column_Vector := Column2(0.0, 1.0);
   X3 : constant Column_Vector := Column2(1.0, 0.0);
   X4 : constant Column_Vector := Column2(1.0, 1.0);

   Y1, Y2, Y3, Y4 : Column_Vector;

   P : Column_Vector;

   Epochs : constant Positive := 5000;
   LR      : constant Float := 0.1;
begin
   -- Build a simple model: 2 inputs -> 1 sigmoid output
   Create(M, Loss => CrossEntropy);
   Add_Dense(M, Inputs => 2, Outputs => 1, Act => Sigmoid, Random_Bias => True);

   -- Create label column-vectors (single-element columns)
   declare
      T : Matrix;
   begin
      T := Matrix_With_Num(1, 1, 0.0);
      Y1 := To_Column_Vector(T);
      Delete(T);

      T := Matrix_With_Num(1, 1, 0.0);
      Y2 := To_Column_Vector(T);
      Delete(T);

      T := Matrix_With_Num(1, 1, 0.0);
      Y3 := To_Column_Vector(T);
      Delete(T);

      T := Matrix_With_Num(1, 1, 1.0);
      Y4 := To_Column_Vector(T);
      Delete(T);
   end;

   -- Training loop (very small dataset)
   for E in 1 .. Epochs loop
      -- train on each sample (SGD)
      Train_Step(M, X1, Y1, LR => LR);
      Train_Step(M, X2, Y2, LR => LR);
      Train_Step(M, X3, Y3, LR => LR);
      Train_Step(M, X4, Y4, LR => LR);

      if E = 1 or else E mod 1000 = 0 then
         Put("Epoch " & E'Image & ": ");

         P := Forward(M, X1);
         Put(P, Fore => 0, Aft => 3, Exp => 0);
         Delete(P);
         Put(" - ");

         P := Forward(M, X2);
         Put(P, Fore => 0, Aft => 3, Exp => 0);
         Delete(P);
         Put(" - ");

         P := Forward(M, X3);
         Put(P, Fore => 0, Aft => 3, Exp => 0);
         Delete(P);
         Put(" - ");

         P := Forward(M, X4);
         Put(P, Fore => 0, Aft => 3, Exp => 0);
         Delete(P);

         New_Line;
      end if;
   end loop;

   -- Final predictions
   Put_Line("Final predictions:");
   P := Forward(M, X1); Put(P); Delete(P);
   P := Forward(M, X2); Put(P); Delete(P);
   P := Forward(M, X3); Put(P); Delete(P);
   P := Forward(M, X4); Put(P); Delete(P);

   -- Cleanup
   Delete(Y1);
   Delete(Y2);
   Delete(Y3);
   Delete(Y4);

   Clear(M);
end Nn;
