with Ada.Text_IO;         use Ada.Text_IO;
with Ada.Float_Text_IO;   use Ada.Float_Text_IO;
with Ada.Numerics.Float_Random;

with Gusjo.Math.Linalg;   use Gusjo.Math.Linalg;
with Gusjo.Math;          use Gusjo.Math;
with Gusjo.Ai.LinReg;    use Gusjo.Ai.LinReg;

procedure LinReg is
   -- Minimal linear regression example
   -- Data: y = 1 + 2*x
   X : Matrix;
   y : Column_Vector;
   Model : LinReg_Model;
   P : Column_Vector;
   -- Create training data
   Obs1 : Row_Vector := Row3(1.0, 0.0, 0.0);
   Obs_y_1 : Row_Vector := Row1(1.0);
   
   Obs2 : Row_Vector := Row3(1.0, 1.0, 1.0);
   Obs_y_2 : Row_Vector := Row1(3.0);
   
   Obs3 : Row_Vector := Row3(1.0, 3.0, 4.0);
   Obs_y_3 : Row_Vector := Row1(5.0);
   
   Obs4 : Row_Vector := Row3(1.0, 4.0, 5.0);
   Obs_y_4 : Row_Vector := Row1(7.0);
   
   Obs5 : Row_Vector := Row3(1.0, 5.0, 6.0);
   Obs_y_5 : Row_Vector := Row1(9.0);
   
   Obs6 : Row_Vector := Row3(1.0, 6.0, 7.0);
   Obs_y_6 : Row_Vector := Row1(11.0);
   
   Obs7 : Row_Vector := Row3(1.0, 7.0, 8.0);
   Obs_y_7 : Row_Vector := Row1(13.0);
   
   Obs8 : Row_Vector := Row3(1.0, 8.0, 9.0);
   Obs_y_8 : Row_Vector := Row1(15.0);
   
   Obs9 : Row_Vector := Row3(1.0, 9.0, 10.0);
   Obs_y_9 : Row_Vector := Row1(17.0);
   
   Obs10 : Row_Vector := Row3(1.0, 10.0, 11.0);
   Obs_y_10 : Row_Vector := Row1(19.0);

   X_Parts : Row_Vector_Array := (Obs1, Obs2, Obs3, Obs4, Obs5, Obs6, Obs7, Obs8, Obs9, Obs10);
   Y_Parts : Row_Vector_Array := (Obs_y_1, Obs_y_2, Obs_y_3, Obs_y_4, Obs_y_5, Obs_y_6, Obs_y_7, Obs_y_8, Obs_y_9, Obs_y_10);
   Y_Parts_Stacked : Matrix := VStack_Rows(Y_Parts);
begin
   X := VStack_Rows(X_Parts);
   y := To_Column_Vector(Y_Parts_Stacked);
   
   -- Train
   Model := Train(X, y);
   
   -- Predict
   P := Predict(Model, X);
   
   -- Results
   Put_Line("=== Linear Regression Example ===");
   Put_Line("Training data: (x1, x2, y) = (0, 0, 1), (1, 1, 3), (2, 4, 9)");
   Put_Line("Expected: y = 1 + 4*x1 - 2*x2");
   Put_Line("Learned weights:");
   Put(Weights(Model));
   New_Line;
   
   Put_Line("R2 Score:");
   Put(R2_Score(Model), Fore => 0, Aft => 20, Exp => 0);
   New_Line;
   New_Line;
   
   Put_Line("Predictions on training set:");
   Put(P);
   
   -- Cleanup
   Delete(X);
   Delete(y);
   Delete(P);
   Delete(Obs1);
   Delete(Obs2);
   Delete(Obs3);
   Delete(Obs4);
   Delete(Obs5);
   Delete(Obs6);
   Delete(Obs7);
   Delete(Obs8);
   Delete(Obs9);
   Delete(Obs10);
   Delete(Obs_y_1);
   Delete(Obs_y_2);
   Delete(Obs_y_3);
   Delete(Obs_y_4);
   Delete(Obs_y_5);
   Delete(Obs_y_6);
   Delete(Obs_y_7);
   Delete(Obs_y_8);
   Delete(Obs_y_9);
   Delete(Obs_y_10);
   Delete(Y_Parts_Stacked);
end LinReg;
