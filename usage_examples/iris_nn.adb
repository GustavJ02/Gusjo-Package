with Ada.Text_IO; use Ada.Text_IO;
with Ada.Float_Text_IO; use Ada.Float_Text_IO;

with Gusjo.Ai; use Gusjo.Ai;
with Gusjo.Ai.Nn; use Gusjo.Ai.Nn;
with Gusjo.Math; use Gusjo.Math;
with Gusjo.Data.Frame; use Gusjo.Data.Frame;
with Gusjo.Math.Linalg; use Gusjo.Math.Linalg;

procedure Iris_Nn is
   Feature_Cols : constant Gusjo.Data.Integer_Array := (2, 3, 4, 5);
   Epochs : constant Positive := 1000;
   LR : constant Float := 0.01;

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

   procedure Print_Accuracy(Label : String;
                            Predicted, Actual : Indices_Array) is
   begin
      Put(Label);
      Put(Accuracy(Predicted, Actual), Fore => 2, Aft => 4, Exp => 0);
      New_Line;
   end Print_Accuracy;

   DF : DataFrame_Type;
   Splits : Train_Test_Split_Type;
   Net : Model;
begin
   Put_Line("Loading iris dataset...");
   Load_CSV("iris.csv", DF);

   Put_Line("Splitting dataset into train/test...");
   Splits := Split(DF, 0.8);

   declare
      Train_DF : constant DataFrame_Type := Train(Splits);
      Test_DF  : constant DataFrame_Type := Test(Splits);

      Train_X : Matrix := Feature_Matrix(Train_DF, Feature_Cols);
      Test_X  : Matrix := Feature_Matrix(Test_DF, Feature_Cols);

      Train_Labels : Indices_Array(1 .. Row_Count(Train_DF)) := Response_Labels(Train_DF, 6);
      Test_Labels  : Indices_Array(1 .. Row_Count(Test_DF)) := Response_Labels(Test_DF, 6);

      Train_Y : Matrix := OneHot_From_Labels(Train_Labels, 3);
      Test_Y  : Matrix := OneHot_From_Labels(Test_Labels, 3);
   begin
      Create(Net, Loss => CrossEntropy);
      Add_Dense(Net, Inputs => 4, Outputs => 10, Act => ReLU, Random_Bias => True);
      Add_Dense(Net, Inputs => 10, Outputs => 3, Act => Softmax, Random_Bias => True);

      Put_Line("Training NN classifier...");
      Train_Batch(Net, Train_X, Train_Y, LR, Epochs);

      declare
         Test_Pred : constant Indices_Array := Argmax_Columns(Forward_Batch(Net, Test_X));
      begin
         Print_Accuracy("Final test accuracy:", Test_Pred, Test_Labels);
      end;

      Delete(Train_X);
      Delete(Test_X);
      Delete(Train_Y);
      Delete(Test_Y);

      Clear(Net);
   end;
end Iris_Nn;
