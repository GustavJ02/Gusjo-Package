--  DataFrame implementation with CSV support
with Ada.Text_Io; use Ada.Text_Io;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Maps;
with Ada.Numerics.Float_Random;

with Gusjo.Math; use Gusjo.Math;
with Gusjo.Math.Linalg; use Gusjo.Math.Linalg;

package body Gusjo.Data.Frame is

   use Ada.Strings;
   use Ada.Strings.Fixed;

   type Field_Array is array (Natural range <>) of Unbounded_String;
   type Row_Index_Array is array (Positive range <>) of Positive;

   type String_Set is array (Positive range <>) of Unbounded_String;

   function Build_Subframe(
      DF : DataFrame_Type;
      Rows : Row_Index_Array) return DataFrame_Type;

   function Shuffled_Row_Indices(Count : Positive) return Row_Index_Array;

   --  Helper: split CSV line by delimiter
   procedure Split_CSV_Line(
      Line : String;
      Delimiter : Character;
      Fields : out Field_Array;
      Field_Count : out Natural) is
      Field_Idx : Natural := Fields'First - 1;
      Current_Field : Unbounded_String;
      In_Quotes : Boolean := False;
      I : Integer := Line'First;
   begin
      Current_Field := Null_Unbounded_String;

      while I <= Line'Last loop
         if Line(I) = '"' then
            In_Quotes := not In_Quotes;
         elsif Line(I) = Delimiter and not In_Quotes then
            if Field_Idx < Fields'Last then
               Field_Idx := Field_Idx + 1;
               Fields(Field_Idx) := Current_Field;
               Current_Field := Null_Unbounded_String;
            end if;
         else
            Append(Current_Field, Line(I));
         end if;
         I := I + 1;
      end loop;

      --  Add last field
      if Field_Idx < Fields'Last then
         Field_Idx := Field_Idx + 1;
         Fields(Field_Idx) := Current_Field;
      end if;
      Field_Count := Field_Idx - Fields'First + 1;
   end Split_CSV_Line;

   function Shuffled_Row_Indices(Count : Positive) return Row_Index_Array is
      Gen : Ada.Numerics.Float_Random.Generator;
      Indices : Row_Index_Array(1 .. Count);
   begin
      for I in Indices'Range loop
         Indices(I) := I;
      end loop;

      Ada.Numerics.Float_Random.Reset(Gen);

      if Count > 1 then
         for I in reverse 2 .. Count loop
            declare
               J_Raw : constant Integer :=
                  Integer(Float(I) * Ada.Numerics.Float_Random.Random(Gen));
               J : Positive := Positive(Integer'Max(1, Integer'Min(Integer(I), J_Raw + 1)));
               Temp : Positive;
            begin
               Temp := Indices(I);
               Indices(I) := Indices(J);
               Indices(J) := Temp;
            end;
         end loop;
      end if;

      return Indices;
   end Shuffled_Row_Indices;

   function Build_Subframe(
      DF : DataFrame_Type;
      Rows : Row_Index_Array) return DataFrame_Type is
      Result : DataFrame_Type;
      Capacity : constant Positive := Positive(Natural'Max(1, Rows'Length));
   begin
      Result.Num_Cols := DF.Num_Cols;
      Result.Num_Rows := 0;

      for Col in 1 .. DF.Num_Cols loop
         Result.Column_Names(Col) := DF.Column_Names(Col);

         case DF.Columns(Col).Kind is
            when Gusjo.Data.Integer_Type =>
               Result.Columns(Col).Kind := Gusjo.Data.Integer_Type;
               Result.Columns(Col).Int_Col := new Integer_Column.Column_Type(Capacity);
            when Gusjo.Data.Float_Type =>
               Result.Columns(Col).Kind := Gusjo.Data.Float_Type;
               Result.Columns(Col).Float_Col := new Float_Column.Column_Type(Capacity);
            when Gusjo.Data.String_Type =>
               Result.Columns(Col).Kind := Gusjo.Data.String_Type;
               Result.Columns(Col).String_Col := new String_Column.Column_Type(Capacity);
         end case;
      end loop;

      for Row_Index of Rows loop
         if Row_Index < 1 or else Row_Index > DF.Num_Rows then
            raise Index_Out_Of_Bounds with "Row index out of bounds";
         end if;

         for Col in 1 .. DF.Num_Cols loop
            case DF.Columns(Col).Kind is
               when Gusjo.Data.Integer_Type =>
                  Integer_Column.Append(
                     Result.Columns(Col).Int_Col.all,
                     Integer_Column.Get(DF.Columns(Col).Int_Col.all, Row_Index));
               when Gusjo.Data.Float_Type =>
                  Float_Column.Append(
                     Result.Columns(Col).Float_Col.all,
                     Float_Column.Get(DF.Columns(Col).Float_Col.all, Row_Index));
               when Gusjo.Data.String_Type =>
                  String_Column.Append(
                     Result.Columns(Col).String_Col.all,
                     String_Column.Get(DF.Columns(Col).String_Col.all, Row_Index));
            end case;
         end loop;

         Result.Num_Rows := Result.Num_Rows + 1;
      end loop;

      return Result;
   end Build_Subframe;

   procedure Load_CSV(File_Path : String; DF : out DataFrame_Type) is
      File : File_Type;
      Line : String(1 .. 1000);
      Line_Len : Natural;
      Header_Fields : Field_Array(1 .. Max_Cols);
      Data_Fields : Field_Array(1 .. Max_Cols);
      Header_Count : Natural;
      Data_Count : Natural;
      Row_Num : Natural := 0;
      First_Row : Boolean := True;
   begin
      DF.Num_Rows := 0;
      DF.Num_Cols := 0;

      Open(File, In_File, File_Path);

      while not End_Of_File(File) loop
         Get_Line(File, Line, Line_Len);

         if Line_Len > 0 then
            if First_Row then
               --  Parse header
               Split_CSV_Line(Line(1 .. Line_Len), ',', Header_Fields, Header_Count);
               DF.Num_Cols := Header_Count;

               --  Initialize columns based on header
               for I in 1 .. Header_Count loop
                  DF.Column_Names(I) := Header_Fields(I);
                  --  Columns will be created on first data row
               end loop;

               First_Row := False;
            else
               --  Parse data row
               Split_CSV_Line(Line(1 .. Line_Len), ',', Data_Fields, Data_Count);

               if Data_Count = DF.Num_Cols then
                  Row_Num := Row_Num + 1;

                  --  Initialize columns on first data row
                  if Row_Num = 1 then
                     for Col in 1 .. DF.Num_Cols loop
                        declare
                           Val : Gusjo.Data.Value_Type := Gusjo.Data.Parse_Value(
                              To_String(Data_Fields(Col)));
                        begin
                           case Val.Kind is
                              when Gusjo.Data.Integer_Type =>
                                 DF.Columns(Col).Kind := Gusjo.Data.Integer_Type;
                                 DF.Columns(Col).Int_Col := new Integer_Column.Column_Type(Max_Rows);
                              when Gusjo.Data.Float_Type =>
                                 DF.Columns(Col).Kind := Gusjo.Data.Float_Type;
                                 DF.Columns(Col).Float_Col := new Float_Column.Column_Type(Max_Rows);
                              when Gusjo.Data.String_Type =>
                                 DF.Columns(Col).Kind := Gusjo.Data.String_Type;
                                 DF.Columns(Col).String_Col := new String_Column.Column_Type(Max_Rows);
                           end case;
                        end;
                     end loop;
                  end if;

                  --  Append data to columns
                  for Col in 1 .. DF.Num_Cols loop
                     declare
                        Val : Gusjo.Data.Value_Type := Gusjo.Data.Parse_Value(
                           To_String(Data_Fields(Col)));
                     begin
                        case DF.Columns(Col).Kind is
                           when Gusjo.Data.Integer_Type =>
                              Integer_Column.Append(DF.Columns(Col).Int_Col.all,
                                 Gusjo.Data.To_Integer(Val));
                           when Gusjo.Data.Float_Type =>
                              Float_Column.Append(DF.Columns(Col).Float_Col.all,
                                 Gusjo.Data.To_Float(Val));
                           when Gusjo.Data.String_Type =>
                              String_Column.Append(DF.Columns(Col).String_Col.all,
                                 Data_Fields(Col));
                        end case;
                     end;
                  end loop;
               end if;
            end if;
         end if;
      end loop;

      Close(File);
      DF.Num_Rows := Row_Num;
   exception
      when Name_Error =>
         raise CSV_Error with "File not found: " & File_Path;
      when others =>
         if Is_Open(File) then
            Close(File);
         end if;
         raise CSV_Error with "Error reading CSV file";
   end Load_CSV;

   procedure Display(DF : in DataFrame_Type; Max_Rows_Display : Natural := 10) is
      Rows_To_Show : constant Natural :=
         Natural'Min(Max_Rows_Display, DF.Num_Rows);
   begin
      --  Print header
      for Col in 1 .. DF.Num_Cols loop
         Put(To_String(DF.Column_Names(Col)));
         if Col < DF.Num_Cols then
            Put(", ");
         end if;
      end loop;
      New_Line;

      --  Print rows
      for Row in 1 .. Rows_To_Show loop
         for Col in 1 .. DF.Num_Cols loop
            case DF.Columns(Col).Kind is
               when Gusjo.Data.Integer_Type =>
                  Put(Integer_Column.Get(DF.Columns(Col).Int_Col.all, Row)'Image);
               when Gusjo.Data.Float_Type =>
                  Put(Float_Column.Get(DF.Columns(Col).Float_Col.all, Row)'Image);
               when Gusjo.Data.String_Type =>
                  Put(To_String(String_Column.Get(DF.Columns(Col).String_Col.all, Row)));
            end case;
            if Col < DF.Num_Cols then
               Put(", ");
            end if;
         end loop;
         New_Line;
      end loop;

      if DF.Num_Rows > Rows_To_Show then
         Put_Line("... (" & Natural'Image(DF.Num_Rows - Rows_To_Show) & " more rows)");
      end if;
   end Display;

   function Row_Count(DF : DataFrame_Type) return Natural is
   begin
      return DF.Num_Rows;
   end Row_Count;

   function Col_Count(DF : DataFrame_Type) return Natural is
   begin
      return DF.Num_Cols;
   end Col_Count;

   function Column_Name(DF : DataFrame_Type; Col_Idx : Positive) return String is
   begin
      if Col_Idx > DF.Num_Cols then
         raise Index_Out_Of_Bounds with "Column index out of bounds";
      end if;
      return To_String(DF.Column_Names(Col_Idx));
   end Column_Name;

   function Column_Kind_At(DF : DataFrame_Type; Col_Idx : Positive) 
      return Gusjo.Data.Column_Kind is
   begin
      if Col_Idx > DF.Num_Cols then
         raise Index_Out_Of_Bounds with "Column index out of bounds";
      end if;
      return DF.Columns(Col_Idx).Kind;
   end Column_Kind_At;

   function Get_Integer(DF : DataFrame_Type; Row : Positive; Col : Positive) return Integer is
   begin
      if Row > DF.Num_Rows or Col > DF.Num_Cols then
         raise Index_Out_Of_Bounds with "Index out of bounds";
      end if;
      case DF.Columns(Col).Kind is
         when Gusjo.Data.Integer_Type =>
            return Integer_Column.Get(DF.Columns(Col).Int_Col.all, Row);
         when Gusjo.Data.Float_Type =>
            return Integer(Float_Column.Get(DF.Columns(Col).Float_Col.all, Row));
         when Gusjo.Data.String_Type =>
            raise Gusjo.Data.Conversion_Error with "Cannot convert string to integer";
      end case;
   end Get_Integer;

   function Get_Float(DF : DataFrame_Type; Row : Positive; Col : Positive) return Float is
   begin
      if Row > DF.Num_Rows or Col > DF.Num_Cols then
         raise Index_Out_Of_Bounds with "Index out of bounds";
      end if;
      case DF.Columns(Col).Kind is
         when Gusjo.Data.Float_Type =>
            return Float_Column.Get(DF.Columns(Col).Float_Col.all, Row);
         when Gusjo.Data.Integer_Type =>
            return Float(Integer_Column.Get(DF.Columns(Col).Int_Col.all, Row));
         when others =>
            raise Gusjo.Data.Conversion_Error with "Cannot convert string column to float";
      end case;
   end Get_Float;

   function Get_String(DF : DataFrame_Type; Row : Positive; Col : Positive) return String is
   begin
      if Row > DF.Num_Rows or Col > DF.Num_Cols then
         raise Index_Out_Of_Bounds with "Index out of bounds";
      end if;
      case DF.Columns(Col).Kind is
         when Gusjo.Data.String_Type =>
            return To_String(String_Column.Get(DF.Columns(Col).String_Col.all, Row));
         when Gusjo.Data.Integer_Type =>
            return Integer_Column.Get(DF.Columns(Col).Int_Col.all, Row)'Image;
         when Gusjo.Data.Float_Type =>
            return Float_Column.Get(DF.Columns(Col).Float_Col.all, Row)'Image;
      end case;
   end Get_String;

   function Extract_Features(
      DF : DataFrame_Type;
      Feature_Cols : Gusjo.Data.Integer_Array) return Gusjo.Data.Value_Type_Array is
      Total_Elements : constant Natural := DF.Num_Rows * Feature_Cols'Length;
      Result : Gusjo.Data.Value_Type_Array(0 .. Total_Elements - 1);
      Idx : Natural := 0;
   begin
      for Row in 1 .. DF.Num_Rows loop
         for Col_Offset in Feature_Cols'Range loop
            declare
               Col : constant Positive := Feature_Cols(Col_Offset);
            begin
               if Col > DF.Num_Cols then
                  raise Index_Out_Of_Bounds with "Feature column index out of bounds";
               end if;

               case DF.Columns(Col).Kind is
                  when Gusjo.Data.Integer_Type =>
                     Result(Idx) := (
                        Kind => Gusjo.Data.Integer_Type,
                        Int_Val => Integer_Column.Get(DF.Columns(Col).Int_Col.all, Row)
                     );
                  when Gusjo.Data.Float_Type =>
                     Result(Idx) := (
                        Kind => Gusjo.Data.Float_Type,
                        Float_Val => Float_Column.Get(DF.Columns(Col).Float_Col.all, Row)
                     );
                  when Gusjo.Data.String_Type =>
                     raise Gusjo.Data.Conversion_Error with
                        "String column cannot be used as feature";
               end case;
               Idx := Idx + 1;
            end;
         end loop;
      end loop;
      return Result;
   end Extract_Features;

   function Extract_Response(
      DF : DataFrame_Type;
      Response_Col : Positive) return Gusjo.Data.Value_Type_Array is
      Result : Gusjo.Data.Value_Type_Array(1 .. DF.Num_Rows);
   begin
      if Response_Col > DF.Num_Cols then
         raise Index_Out_Of_Bounds with "Response column index out of bounds";
      end if;

      for Row in 1 .. DF.Num_Rows loop
         case DF.Columns(Response_Col).Kind is
            when Gusjo.Data.Integer_Type =>
               Result(Row) := (
                  Kind => Gusjo.Data.Integer_Type,
                  Int_Val => Integer_Column.Get(DF.Columns(Response_Col).Int_Col.all, Row)
               );
            when Gusjo.Data.Float_Type =>
               Result(Row) := (
                  Kind => Gusjo.Data.Float_Type,
                  Float_Val => Float_Column.Get(DF.Columns(Response_Col).Float_Col.all, Row)
               );
            when Gusjo.Data.String_Type =>
               raise Gusjo.Data.Conversion_Error with
                  "String column cannot be used as response";
         end case;
      end loop;
      return Result;
   end Extract_Response;

   function Split(
      DF : DataFrame_Type;
      Train_Ratio : Float) return Train_Test_Split_Type is
      Train_Count : constant Natural := Natural(Float(DF.Num_Rows) * Train_Ratio);
   begin
      if DF.Num_Rows = 0 then
         raise Constraint_Error with "Split: dataframe has no rows";
      end if;

      if Train_Ratio <= 0.0 or else Train_Ratio >= 1.0 then
         raise Constraint_Error with "Split: train ratio must be between 0.0 and 1.0";
      end if;

      if Train_Count < 1 or else Train_Count >= DF.Num_Rows then
         raise Constraint_Error with "Split: train ratio produces an invalid split";
      end if;

      declare
         Indices : constant Row_Index_Array := Shuffled_Row_Indices(Positive(DF.Num_Rows));
      begin
         return (
            Train => Build_Subframe(DF, Indices(1 .. Train_Count)),
            Test  => Build_Subframe(DF, Indices(Train_Count + 1 .. Indices'Last)));
      end;
   end Split;

   function Split(
      DF : DataFrame_Type;
      Train_Ratio : Float;
      Test_Ratio : Float) return Train_Valid_Test_Split_Type is
      Train_Count : constant Natural := Natural(Float(DF.Num_Rows) * Train_Ratio);
      Test_Count : constant Natural := Natural(Float(DF.Num_Rows) * Test_Ratio);
      Valid_Count : constant Natural := DF.Num_Rows - Train_Count - Test_Count;
   begin
      if DF.Num_Rows = 0 then
         raise Constraint_Error with "Split: dataframe has no rows";
      end if;

      if Train_Ratio <= 0.0 or else Test_Ratio <= 0.0 then
         raise Constraint_Error with "Split: train and test ratios must be positive";
      end if;

      if Train_Ratio + Test_Ratio >= 1.0 then
         raise Constraint_Error with "Split: train plus test ratio must be less than 1.0";
      end if;

      if Train_Count < 1 or else Test_Count < 1 or else Valid_Count = 0 then
         raise Constraint_Error with "Split: ratios produce an invalid train/valid/test split";
      end if;

      declare
         Indices : constant Row_Index_Array := Shuffled_Row_Indices(Positive(DF.Num_Rows));
      begin
         return (
            Train => Build_Subframe(DF, Indices(1 .. Train_Count)),
            Valid => Build_Subframe(DF, Indices(Train_Count + 1 .. Train_Count + Valid_Count)),
            Test  => Build_Subframe(DF, Indices(Train_Count + Valid_Count + 1 .. Indices'Last)));
      end;
   end Split;

   function Train(Split : Train_Test_Split_Type) return DataFrame_Type is
   begin
      return Split.Train;
   end Train;

   function Test(Split : Train_Test_Split_Type) return DataFrame_Type is
   begin
      return Split.Test;
   end Test;

   function Train(Split : Train_Valid_Test_Split_Type) return DataFrame_Type is
   begin
      return Split.Train;
   end Train;

   function Valid(Split : Train_Valid_Test_Split_Type) return DataFrame_Type is
   begin
      return Split.Valid;
   end Valid;

   function Test(Split : Train_Valid_Test_Split_Type) return DataFrame_Type is
   begin
      return Split.Test;
   end Test;

   function Feature_Matrix(
      DF : DataFrame_Type;
      Feature_Cols : Gusjo.Data.Integer_Array) return Matrix is
   begin
      if DF.Num_Rows = 0 then
         raise Constraint_Error with "Feature_Matrix: dataframe has no rows";
      end if;

      if Feature_Cols'Length = 0 then
         raise Constraint_Error with "Feature_Matrix: no feature columns selected";
      end if;

      declare
         Samples : Column_Vector_Array(1 .. DF.Num_Rows);
      begin
         for Row in 1 .. DF.Num_Rows loop
            declare
               Values : Float_Array(1 .. Feature_Cols'Length);
               Pos : Natural := 0;
            begin
               for Feature_Col_Idx in Feature_Cols'Range loop
                  declare
                     Col : constant Positive := Positive(Feature_Cols(Feature_Col_Idx));
                  begin
                     if Col > DF.Num_Cols then
                        raise Index_Out_Of_Bounds with "Feature column index out of bounds";
                     end if;

                     Pos := Pos + 1;
                     Values(Pos) := Get_Float(DF, Row, Col);
                  end;
               end loop;

               Samples(Row) := Column_Vector_From_Array(Values);
            end;
         end loop;

         return HStack_Columns(Samples);
      end;
   end Feature_Matrix;

   function Response_Labels(
      DF : DataFrame_Type;
      Response_Col : Positive) return Indices_Array is
   begin
      if DF.Num_Rows = 0 then
         raise Constraint_Error with "Response_Labels: dataframe has no rows";
      end if;

      if Response_Col > DF.Num_Cols then
         raise Index_Out_Of_Bounds with "Response column index out of bounds";
      end if;

      declare
         Labels : Indices_Array(1 .. DF.Num_Rows);
         Class_Names : String_Set(1 .. DF.Num_Rows);
         Class_Count : Natural := 0;
      begin
         case DF.Columns(Response_Col).Kind is
            when Gusjo.Data.Integer_Type =>
               for Row in 1 .. DF.Num_Rows loop
                  Labels(Row) := Positive(Integer_Column.Get(DF.Columns(Response_Col).Int_Col.all, Row));
               end loop;

            when Gusjo.Data.Float_Type =>
               for Row in 1 .. DF.Num_Rows loop
                  Labels(Row) := Positive(Integer(Float_Column.Get(DF.Columns(Response_Col).Float_Col.all, Row)));
               end loop;

            when Gusjo.Data.String_Type =>
               for Row in 1 .. DF.Num_Rows loop
                  declare
                     Value : constant Unbounded_String :=
                        String_Column.Get(DF.Columns(Response_Col).String_Col.all, Row);
                     Found : Boolean := False;
                  begin
                     for Class_Idx in 1 .. Class_Count loop
                        if Class_Names(Class_Idx) = Value then
                           Found := True;
                           exit;
                        end if;
                     end loop;

                     if not Found then
                        Class_Count := Class_Count + 1;
                        Class_Names(Class_Count) := Value;
                     end if;
                  end;
               end loop;

               if Class_Count > 1 then
                  for I in 1 .. Class_Count - 1 loop
                     for J in I + 1 .. Class_Count loop
                        if Class_Names(J) < Class_Names(I) then
                           declare
                              Temp : constant Unbounded_String := Class_Names(I);
                           begin
                              Class_Names(I) := Class_Names(J);
                              Class_Names(J) := Temp;
                           end;
                        end if;
                     end loop;
                  end loop;
               end if;

               for Row in 1 .. DF.Num_Rows loop
                  declare
                     Value : constant Unbounded_String :=
                        String_Column.Get(DF.Columns(Response_Col).String_Col.all, Row);
                  begin
                     for Class_Idx in 1 .. Class_Count loop
                        if Class_Names(Class_Idx) = Value then
                           Labels(Row) := Class_Idx;
                           exit;
                        end if;
                     end loop;
                  end;
               end loop;
         end case;

         return Labels;
      end;
   end Response_Labels;

end Gusjo.Data.Frame;
