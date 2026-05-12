--  Example: Load CSV and extract features for ML training
with Ada.Text_Io; use Ada.Text_Io;
with Gusjo.Data.Frame;

procedure Dataframe is
   DF : Gusjo.Data.Frame.DataFrame_Type;
begin
   Put_Line("=== DataFrame CSV Example ===");
   New_Line;

   --  Load CSV file (assuming a file exists with numeric data)
   Put_Line("Loading iris.csv...");
   Gusjo.Data.Frame.Load_CSV("iris.csv", DF);

   Put_Line("Loaded successfully!");
   Put_Line("Rows: " & Gusjo.Data.Frame.Row_Count(DF)'Image);
   Put_Line("Columns: " & Gusjo.Data.Frame.Col_Count(DF)'Image);
   New_Line;

   --  Display first few rows
   Put_Line("=== Data Preview ===");
   Gusjo.Data.Frame.Display(DF, Max_Rows_Display => 5);
   New_Line;

   --  Display column info
   Put_Line("=== Column Information ===");
   for Col in 1 .. Gusjo.Data.Frame.Col_Count(DF) loop
      Put("Column " & Col'Image & ": " & 
          Gusjo.Data.Frame.Column_Name(DF, Col) & " - ");
      case Gusjo.Data.Frame.Column_Kind_At(DF, Col) is
         when Gusjo.Data.Integer_Type =>
            Put_Line("Integer");
         when Gusjo.Data.Float_Type =>
            Put_Line("Float");
         when Gusjo.Data.String_Type =>
            Put_Line("String");
      end case;
   end loop;
   New_Line;

   --  Example: Extract features (columns 1-4 as features, column 5 as response)
   Put_Line("=== Feature Extraction ===");
   if Gusjo.Data.Frame.Col_Count(DF) >= 5 then
      declare
         Feature_Cols : constant Gusjo.Data.Integer_Array := (1, 2, 3, 4);
         Features : constant Gusjo.Data.Value_Type_Array := 
            Gusjo.Data.Frame.Extract_Features(DF, Feature_Cols);
         Response : constant Gusjo.Data.Value_Type_Array := 
            Gusjo.Data.Frame.Extract_Response(DF, 5);
      begin
         Put_Line("Extracted " & Response'Length'Image & " samples");
         Put_Line("Features per sample: " & Feature_Cols'Length'Image);
         Put_Line("Ready for ML training!");
      end;
   end if;

exception
   when Gusjo.Data.Frame.CSV_Error =>
      Put_Line("Error: Could not load CSV file.");
   when others =>
      Put_Line("Error: Unexpected exception.");
end Dataframe;
