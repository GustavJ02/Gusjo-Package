--  DataFrame type for tabular data with heterogeneous columns
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Gusjo.Math; use Gusjo.Math;
with Gusjo.Data;
with Gusjo.Data.Column;
with Gusjo.Math.Linalg; use Gusjo.Math.Linalg;

package Gusjo.Data.Frame is

   --  Instantiate column types for common element types
   package Integer_Column is new Gusjo.Data.Column(Element_Type => Integer);
   package Float_Column is new Gusjo.Data.Column(Element_Type => Float);
   package String_Column is new Gusjo.Data.Column(Element_Type => Unbounded_String);

   use Integer_Column, Float_Column, String_Column;

   --  Maximum size for columns and dataframe
   Max_Rows : constant Positive := 10000;
   Max_Cols : constant Positive := 100;

   type Column_Reference is record
      Kind : Gusjo.Data.Column_Kind;
      Int_Col : access Integer_Column.Column_Type;
      Float_Col : access Float_Column.Column_Type;
      String_Col : access String_Column.Column_Type;
   end record;

   type Column_Name_Array is array(1 .. Max_Cols) of Unbounded_String;
   type Column_Ref_Array is array(1 .. Max_Cols) of Column_Reference;

   type DataFrame_Type is record
      Num_Rows : Natural := 0;
      Num_Cols : Natural := 0;
      Column_Names : Column_Name_Array;
      Columns : Column_Ref_Array;
   end record;

   type Train_Test_Split_Type is record
      Train : DataFrame_Type;
      Test : DataFrame_Type;
   end record;

   type Train_Valid_Test_Split_Type is record
      Train : DataFrame_Type;
      Valid : DataFrame_Type;
      Test  : DataFrame_Type;
   end record;

   --  Load CSV file into DataFrame with automatic type detection
   --  First row is treated as header (column names)
   procedure Load_CSV(File_Path : String; DF : out DataFrame_Type);

   --  Display DataFrame (first N rows)
   procedure Display(DF : in DataFrame_Type; Max_Rows_Display : Natural := 10);

   --  Get number of rows
   function Row_Count(DF : DataFrame_Type) return Natural;

   --  Get number of columns
   function Col_Count(DF : DataFrame_Type) return Natural;

   --  Get column name by index (1-based)
   function Column_Name(DF : DataFrame_Type; Col_Idx : Positive) return String;

   --  Get column kind (type) by index (1-based)
   function Column_Kind_At(DF : DataFrame_Type; Col_Idx : Positive) 
      return Gusjo.Data.Column_Kind;

   --  Get integer value at row, column
   function Get_Integer(DF : DataFrame_Type; Row : Positive; Col : Positive) return Integer;

   --  Get float value at row, column
   function Get_Float(DF : DataFrame_Type; Row : Positive; Col : Positive) return Float;

   --  Get string value at row, column
   function Get_String(DF : DataFrame_Type; Row : Positive; Col : Positive) return String;

   --  Extract feature matrix from selected columns (returns flat array)
   --  Columns must be numeric (Integer or Float)
   function Extract_Features(
      DF : DataFrame_Type;
      Feature_Cols : Gusjo.Data.Integer_Array) return Gusjo.Data.Value_Type_Array;

   --  Extract response vector from single column
   function Extract_Response(
      DF : DataFrame_Type;
      Response_Col : Positive) return Gusjo.Data.Value_Type_Array;

   --  Split into train/test using ratios in the range (0.0, 1.0)
   function Split(
      DF : DataFrame_Type;
      Train_Ratio : Float) return Train_Test_Split_Type;

   --  Split into train/valid/test using train and test ratios.
   --  Validation ratio is the remainder.
   function Split(
      DF : DataFrame_Type;
      Train_Ratio : Float;
      Test_Ratio : Float) return Train_Valid_Test_Split_Type;

   --  Helper accessors for split results
   function Train(Split : Train_Test_Split_Type) return DataFrame_Type;
   function Test(Split : Train_Test_Split_Type) return DataFrame_Type;

   function Train(Split : Train_Valid_Test_Split_Type) return DataFrame_Type;
   function Valid(Split : Train_Valid_Test_Split_Type) return DataFrame_Type;
   function Test(Split : Train_Valid_Test_Split_Type) return DataFrame_Type;

   --  ML helpers
   function Feature_Matrix(
      DF : DataFrame_Type;
      Feature_Cols : Gusjo.Data.Integer_Array) return Matrix;

   function Response_Labels(
      DF : DataFrame_Type;
      Response_Col : Positive) return Indices_Array;

   --  Exceptions
   CSV_Error : exception;
   Index_Out_Of_Bounds : exception;

end Gusjo.Data.Frame;
