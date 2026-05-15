with Ada.Text_IO; use Ada.Text_IO;
with Ada.Float_Text_IO; use Ada.Float_Text_IO;
with Ada.Directories; use Ada.Directories;

with Gusjo.Ai; use Gusjo.Ai;
with Gusjo.Ai.Nn; use Gusjo.Ai.Nn;
with Gusjo.Math; use Gusjo.Math;
with Gusjo.Data.Frame; use Gusjo.Data.Frame;
with Gusjo.Math.Linalg; use Gusjo.Math.Linalg;
with Gusjo.Math.Optimization; use Gusjo.Math.Optimization;

procedure Iris_Nn is
   Feature_Cols : constant Gusjo.Data.Integer_Array := (2, 3, 4, 5);
   Optimizer : constant Optimizer_Config := (
      Method => Gradient_Descent,
      Learning_Rate => 0.02,
      Max_Epochs => 10000,
      Gradient_Tolerance => 1.0E-5,
      Loss_Tolerance => 1.0E-5,
      Clip_Threshold => 0.0);

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
   Training_Result : Optimization_Result;
begin
   Put_Line("Loading iris dataset...");
   If Exists("data/datafiles/iris.adadf") then
      Load_Binary("data/datafiles/iris.adadf", DF);
   else
      Put_Line("Binary dataframe not found, loading from CSV...");
      Load_CSV("python_comparison/iris.csv", DF);
      Put_Line("Saving binary dataframe for faster loading next time...");
      Save_Binary("data/datafiles/iris.adadf", DF);
   end if;

   Put_Line("Splitting dataset into train/test...");
   Splits := Split(DF, 0.6);

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
      Train_Batch(Net, Train_X, Train_Y, Optimizer, Training_Result);
      Put_Line("Epochs run: " & Natural'Image(Training_Result.Epochs_Run));
      Put_Line("Stop reason: " & Stop_Reason'Image(Training_Result.Reason));
      Put("Final train loss: ");
      Put(Training_Result.Final_Loss, Fore => 2, Aft => 6, Exp => 0);
      New_Line;
      Put("Final gradient norm: ");
      Put(Training_Result.Final_Gradient_Norm, Fore => 2, Aft => 6, Exp => 0);
      New_Line;

      declare
         Test_Pred : constant Indices_Array := Argmax_Columns(Forward_Batch(Net, Test_X));
      begin
         Print_Accuracy("Final test accuracy:", Test_Pred, Test_Labels);
         Put_Line("Confusion Matrix:");
         declare
            CM : Matrix := Confusion_Matrix(Test_Pred, Test_Labels);
         begin
            Put(CM);
            Delete(CM);
         end;
      end;

      Delete(Train_X);
      Delete(Test_X);
      Delete(Train_Y);
      Delete(Test_Y);

      Clear(Net);
   end;
end Iris_Nn;
