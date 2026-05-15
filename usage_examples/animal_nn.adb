with Ada.Text_IO;             use Ada.Text_IO;
with Ada.Float_Text_IO;       use Ada.Float_Text_IO;
with Ada.Directories;         use Ada.Directories;

with Gusjo.Ai;                use Gusjo.Ai;
with Gusjo.Ai.Nn;             use Gusjo.Ai.Nn;
with Gusjo.Math;              use Gusjo.Math;
with Gusjo.Data.Frame;        use Gusjo.Data.Frame;
with Gusjo.Math.Linalg;       use Gusjo.Math.Linalg;
with Gusjo.Math.Optimization; use Gusjo.Math.Optimization;

procedure Animal_Nn is

   function Column_Range(First, Last : Positive) return Gusjo.Data.Integer_Array is
      Result : Gusjo.Data.Integer_Array(0 .. Last - First);
   begin
      for I in Result'Range loop
         Result(I) := First + I;
      end loop;

      return Result;
   end Column_Range;

   DF : DataFrame_Type;
   Splits : Train_Test_Split_Type;
   Net : Model;

   Optimizer : constant Optimizer_Config := (
      Method => Gradient_Descent,
      Learning_Rate => 0.02,
      Max_Epochs => 10000,
      Gradient_Tolerance => 1.0E-5,
      Loss_Tolerance => 1.0E-5,
      Clip_Threshold => 0.0);
   Training_Result : Optimization_Result;

begin
   Put_Line("Loading animals dataset...");
   If Exists("data/datafiles/animals.adadf") then
      Load_Binary("data/datafiles/animals.adadf", DF);
   else
      Put_Line("Binary dataframe not found, loading from CSV...");
      Load_CSV("python_comparison/animals.csv", DF);
      Put_Line("Saving binary dataframe for faster loading next time...");
      Save_Binary("data/datafiles/animals.adadf", DF);
   end if;
   
   Put_Line("=== Data Preview ===");
   Display(DF, Max_Rows_Display => 5);

   Put_Line("Splitting dataset into train/test...");
   Splits := Split(DF, 0.6);

   declare
      Train_DF : constant DataFrame_Type := Train(Splits);
      Test_DF  : constant DataFrame_Type := Test(Splits);
      Feature_Cols : constant Gusjo.Data.Integer_Array := Column_Range(3, Col_Count(Train_DF));

      Train_X : Matrix;
      Test_X  : Matrix;

      Train_Labels : Indices_Array(1 .. Row_Count(Train_DF));
      Test_Labels  : Indices_Array(1 .. Row_Count(Test_DF));

      Train_Y : Matrix;
      Test_Y  : Matrix;
   begin

      Put_Line("Extracting Train features...");
      Train_X := Feature_Matrix(Train_DF, Feature_Cols);
      Put_Line("Extracting Test features...");
      Test_X  := Feature_Matrix(Test_DF, Feature_Cols);

      Put_Line("Extracting Train labels...");
      Train_Labels := Response_Labels(Train_DF, 2);
      Put_Line("Extracting Test labels...");
      Test_Labels  := Response_Labels(Test_DF, 2);

      Put_Line("Converting Train labels to one-hot...");
      Train_Y  := OneHot_From_Labels(Train_Labels, 10);
      Put_Line("Converting Test labels to one-hot...");
      Test_Y  := OneHot_From_Labels(Test_Labels, 10);

      Put_Line("Creating network");
      Create(Net, Loss => CrossEntropy);
      Add_Dense(Net, Inputs => Positive(Feature_Cols'Length), Outputs => 128, Act => ReLU, Random_Bias => True);
      Add_Dense(Net, Inputs => 128, Outputs => 64, Act => ReLU, Random_Bias => True);
      Add_Dense(Net, Inputs => 64, Outputs => 10, Act => Softmax, Random_Bias => True);

      Put_Line("Training NN classifier...");
      Train_Batch(Net, Train_X, Train_Y, Optimizer, Training_Result, Verbose => 1);
      Put_Line("Epochs run: " & Natural'Image(Training_Result.Epochs_Run));
      Put_Line("Stop reason: " & Stop_Reason'Image(Training_Result.Reason));
      Put("Final train loss: ");
      Put(Training_Result.Final_Loss, Fore => 2, Aft => 6, Exp => 0);
      New_Line;
      Put("Final gradient norm: ");
      Put(Training_Result.Final_Gradient_Norm, Fore => 2, Aft => 6, Exp => 0);
      New_Line;

      declare
         Predicted_Labels : Indices_Array := Argmax_Columns(Forward_Batch(Net, Test_X));
      begin
         Put("Test set accuracy: ");
         Put(Accuracy(Predicted_Labels, Test_Labels), Fore => 2, Aft => 4, Exp => 0);
         New_Line;
         declare
            CM : Matrix := Confusion_Matrix(Predicted_Labels, Test_Labels);
         begin
            Put(CM);
            Delete(CM);
         end;
      end;
      Delete(Train_X);
      Delete(Test_X);
      Delete(Train_Y);
      Delete(Test_Y);
   end;
   Delete(DF);
   Clear(Net);
end Animal_Nn;
