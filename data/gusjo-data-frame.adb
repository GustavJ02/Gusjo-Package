--  DataFrame implementation with CSV support
with Ada.Text_Io; use Ada.Text_Io;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.Unbounded.Aux;
with Ada.Strings.Unbounded.Text_IO;
with Ada.Numerics.Float_Random;
with Ada.Unchecked_Deallocation;
with System.Multiprocessors;

with Gusjo.Math; use Gusjo.Math;
with Gusjo.Math.Linalg; use Gusjo.Math.Linalg;

package body Gusjo.Data.Frame is

   use Ada.Strings;
   use Ada.Strings.Fixed;

   type Row_Index_Array is array (Positive range <>) of Positive;

   type String_Set is array (Positive range <>) of Unbounded_String;

   type Field_Reference is record
      Found : Boolean := False;
      First : Natural := 1;
      Last : Natural := 0;
      Needs_Unescape : Boolean := False;
   end record;

   Empty_Column : constant Column_Reference := (
      Kind => Gusjo.Data.String_Type,
      Int_Col => null,
      Float_Col => null,
      String_Col => null);

   procedure Free_Column_Names is new Ada.Unchecked_Deallocation(
      Column_Name_Array,
      Column_Name_Array_Access);

   procedure Free_Column_Refs is new Ada.Unchecked_Deallocation(
      Column_Ref_Array,
      Column_Ref_Array_Access);

   procedure Free_Integer_Column is new Ada.Unchecked_Deallocation(
      Integer_Column.Column_Type,
      Integer_Column_Access);

   procedure Free_Float_Column is new Ada.Unchecked_Deallocation(
      Float_Column.Column_Type,
      Float_Column_Access);

   procedure Free_String_Column is new Ada.Unchecked_Deallocation(
      String_Column.Column_Type,
      String_Column_Access);

   function Build_Subframe(
      DF : DataFrame_Type;
      Rows : Row_Index_Array) return DataFrame_Type;

   procedure Ensure_Column_Capacity(
      DF : in out DataFrame_Type;
      Required_Cols : Natural);

   procedure Free_Column(Col : in out Column_Reference);

   procedure Set_Column_Row_Counts(
      DF : in out DataFrame_Type;
      Count : Natural);

   function CSV_Worker_Count return Positive;

   function Count_CSV_Data_Rows(
      File_Path : String;
      Headers : Boolean) return Natural;

   function CSV_Field_Count(Line : String) return Natural;

   function Next_CSV_Field(
      Line : String;
      Position : in out Natural) return Field_Reference;

   function Field_To_String(
      Line : String;
      Field : Field_Reference) return String;

   function Parse_Integer_Field(
      Line : String;
      Field : Field_Reference) return Integer;

   function Parse_Next_Integer_Field(
      Line : String;
      Position : in out Natural) return Integer;

   function Parse_Float_Field(
      Line : String;
      Field : Field_Reference) return Float;

   function Parse_Next_Float_Field(
      Line : String;
      Position : in out Natural) return Float;

   function Shuffled_Row_Indices(Count : Positive) return Row_Index_Array;

   pragma Inline (Parse_Next_Integer_Field);
   pragma Inline (Parse_Next_Float_Field);

   procedure Free_Column(Col : in out Column_Reference) is
   begin
      if Col.Int_Col /= null then
         Integer_Column.Delete(Col.Int_Col.all);
         Free_Integer_Column(Col.Int_Col);
      end if;

      if Col.Float_Col /= null then
         Float_Column.Delete(Col.Float_Col.all);
         Free_Float_Column(Col.Float_Col);
      end if;

      if Col.String_Col /= null then
         String_Column.Delete(Col.String_Col.all);
         Free_String_Column(Col.String_Col);
      end if;

      Col := Empty_Column;
   end Free_Column;

   procedure Set_Column_Row_Counts(
      DF : in out DataFrame_Type;
      Count : Natural) is
   begin
      for Col in 1 .. DF.Num_Cols loop
         case DF.Columns(Col).Kind is
            when Gusjo.Data.Integer_Type =>
               if DF.Columns(Col).Int_Col /= null then
                  Integer_Column.Set_Row_Count(
                     DF.Columns(Col).Int_Col.all,
                     Count);
               end if;
            when Gusjo.Data.Float_Type =>
               if DF.Columns(Col).Float_Col /= null then
                  Float_Column.Set_Row_Count(
                     DF.Columns(Col).Float_Col.all,
                     Count);
               end if;
            when Gusjo.Data.String_Type =>
               if DF.Columns(Col).String_Col /= null then
                  String_Column.Set_Row_Count(
                     DF.Columns(Col).String_Col.all,
                     Count);
               end if;
         end case;
      end loop;
   end Set_Column_Row_Counts;

   function CSV_Worker_Count return Positive is
      Default_Count : constant Positive :=
         Positive(System.Multiprocessors.Number_Of_CPUs);
   begin
      if Ada.Environment_Variables.Exists("GUSJO_CSV_WORKERS") then
         declare
            Value : constant String :=
               Trim(Ada.Environment_Variables.Value("GUSJO_CSV_WORKERS"), Both);
            Parsed : constant Positive := Positive'Value(Value);
         begin
            return Parsed;
         exception
            when Constraint_Error =>
               null;
         end;
      end if;

      return Default_Count;
   end CSV_Worker_Count;

   function Count_CSV_Data_Rows(
      File_Path : String;
      Headers : Boolean) return Natural is
      Count_File : File_Type;
      Line : Unbounded_String := Null_Unbounded_String;
      Saw_Header : Boolean := False;
      Result : Natural := 0;
   begin
      Open(Count_File, In_File, File_Path);

      while not End_Of_File(Count_File) loop
         Ada.Strings.Unbounded.Text_IO.Get_Line(Count_File, Line);

         if Length(Line) > 0 then
            if Headers and then not Saw_Header then
               Saw_Header := True;
            else
               Result := Result + 1;
            end if;
         end if;
      end loop;

      Close(Count_File);
      return Result;
   exception
      when others =>
         if Is_Open(Count_File) then
            Close(Count_File);
         end if;

         raise;
   end Count_CSV_Data_Rows;

   procedure Ensure_Column_Capacity(
      DF : in out DataFrame_Type;
      Required_Cols : Natural) is
      New_Capacity : Positive;
      New_Names : Column_Name_Array_Access;
      New_Columns : Column_Ref_Array_Access;
      Current_Capacity : Natural := Natural'Max(1, DF.Capacity_Cols);
   begin
      if Required_Cols = 0 then
         return;
      end if;

      if Required_Cols > Max_Cols then
         raise CSV_Error with
            "CSV has too many columns (current file has " &
            Natural'Image(Required_Cols) & ", max is " &
            Natural'Image(Max_Cols) & ")";
      end if;

      if DF.Column_Names /= null
        and then DF.Columns /= null
        and then DF.Capacity_Cols >= Required_Cols
      then
         return;
      end if;

      if Current_Capacity > Max_Cols / 2 then
         New_Capacity := Positive(Required_Cols);
      else
         New_Capacity := Positive(Natural'Min(
            Max_Cols,
            Natural'Max(Required_Cols, Current_Capacity * 2)));
      end if;

      New_Names := new Column_Name_Array(1 .. New_Capacity);
      New_Names.all := (others => Null_Unbounded_String);

      New_Columns := new Column_Ref_Array(1 .. New_Capacity);
      New_Columns.all := (others => Empty_Column);

      if DF.Column_Names /= null then
         for I in 1 .. DF.Num_Cols loop
            New_Names(I) := DF.Column_Names(I);
         end loop;

         Free_Column_Names(DF.Column_Names);
      end if;

      if DF.Columns /= null then
         for I in 1 .. DF.Num_Cols loop
            New_Columns(I) := DF.Columns(I);
         end loop;

         Free_Column_Refs(DF.Columns);
      end if;

      DF.Column_Names := New_Names;
      DF.Columns := New_Columns;
      DF.Capacity_Cols := New_Capacity;
   end Ensure_Column_Capacity;

   function CSV_Field_Count(Line : String) return Natural is
      Len : constant Natural := Line'Length;
      Count : Natural := 1;
      In_Quotes : Boolean := False;
      I : Natural := 1;
   begin
      if Len = 0 then
         return 0;
      end if;

      while I <= Len loop
         declare
            C : constant Character := Line(I);
         begin
            if C = '"' then
               if In_Quotes
                 and then I < Len
                 and then Line(I + 1) = '"'
               then
                  I := I + 1;
               else
                  In_Quotes := not In_Quotes;
               end if;
            elsif C = ',' and then not In_Quotes then
               Count := Count + 1;
            end if;
         end;

         I := I + 1;
      end loop;

      return Count;
   end CSV_Field_Count;

   function Slice_Or_Empty(
      Line : String;
      Low : Natural;
      High : Natural) return String is
   begin
      if High < Low then
         return "";
      end if;

      return Line(Positive(Low) .. Positive(High));
   end Slice_Or_Empty;

   function Next_CSV_Field(
      Line : String;
      Position : in out Natural) return Field_Reference is
      Len : constant Natural := Line'Length;
      Field_Start : constant Natural := Position;
      In_Quotes : Boolean := False;
      I : Natural := Position;
      Needs_Unescape : Boolean := False;
   begin
      if Position = 0 then
         return (Found => False, First => 1, Last => 0, Needs_Unescape => False);
      end if;

      if Position = Len + 1 then
         Position := 0;
         return (
            Found => True,
            First => Field_Start,
            Last => Field_Start - 1,
            Needs_Unescape => False);
      end if;

      while I <= Len loop
         declare
            C : constant Character := Line(I);
         begin
            if C = '"' then
               Needs_Unescape := True;

               if In_Quotes
                 and then I < Len
                 and then Line(I + 1) = '"'
               then
                  I := I + 1;
               else
                  In_Quotes := not In_Quotes;
               end if;
            elsif C = ',' and then not In_Quotes then
               Position := I + 1;
               return (
                  Found => True,
                  First => Field_Start,
                  Last => I - 1,
                  Needs_Unescape => Needs_Unescape);
            end if;
         end;

         I := I + 1;
      end loop;

      Position := 0;
      return (
         Found => True,
         First => Field_Start,
         Last => Len,
         Needs_Unescape => Needs_Unescape);
   end Next_CSV_Field;

   function Field_To_String(
      Line : String;
      Field : Field_Reference) return String is
      Result : Unbounded_String := Null_Unbounded_String;
      In_Quotes : Boolean := False;
      I : Natural := Field.First;
   begin
      if not Field.Found then
         return "";
      end if;

      if not Field.Needs_Unescape then
         return Slice_Or_Empty(Line, Field.First, Field.Last);
      end if;

      while I <= Field.Last loop
         declare
            C : constant Character := Line(I);
         begin
            if C = '"' then
               if In_Quotes
                 and then I < Field.Last
                 and then Line(I + 1) = '"'
               then
                  Append(Result, '"');
                  I := I + 1;
               else
                  In_Quotes := not In_Quotes;
               end if;
            else
               Append(Result, C);
            end if;
         end;

         I := I + 1;
      end loop;

      return To_String(Result);
   end Field_To_String;

   function Parse_Integer_Field(
      Line : String;
      Field : Field_Reference) return Integer is
      I : Natural := Field.First;
      Sign : Integer := 1;
      Value : Integer := 0;
      Has_Digit : Boolean := False;
   begin
      if Field.Needs_Unescape then
         return Integer'Value(Field_To_String(Line, Field));
      end if;

      while I <= Field.Last and then Line(I) = ' ' loop
         I := I + 1;
      end loop;

      if I <= Field.Last then
         if Line(I) = '-' then
            Sign := -1;
            I := I + 1;
         elsif Line(I) = '+' then
            I := I + 1;
         end if;
      end if;

      while I <= Field.Last and then Line(I) in '0' .. '9' loop
         Has_Digit := True;
         Value := Value * 10 + Character'Pos(Line(I)) - Character'Pos('0');
         I := I + 1;
      end loop;

      while I <= Field.Last and then Line(I) = ' ' loop
         I := I + 1;
      end loop;

      if Has_Digit and then I > Field.Last then
         return Sign * Value;
      end if;

      return Integer'Value(Field_To_String(Line, Field));
   end Parse_Integer_Field;

   function Parse_Next_Integer_Field(
      Line : String;
      Position : in out Natural) return Integer is
      Len : constant Natural := Line'Length;
      Start : constant Natural := Position;
      I : Natural := Position;
      Sign : Integer := 1;
      Value : Integer := 0;
      Has_Digit : Boolean := False;
   begin
      if Position = 0 then
         raise Constraint_Error;
      end if;

      if I <= Len and then Line(I) = '"' then
         declare
            Field : constant Field_Reference := Next_CSV_Field(Line, Position);
         begin
            return Parse_Integer_Field(Line, Field);
         end;
      end if;

      while I <= Len and then Line(I) = ' ' loop
         I := I + 1;
      end loop;

      if I <= Len then
         if Line(I) = '-' then
            Sign := -1;
            I := I + 1;
         elsif Line(I) = '+' then
            I := I + 1;
         end if;
      end if;

      while I <= Len and then Line(I) in '0' .. '9' loop
         Has_Digit := True;
         Value := Value * 10 + Character'Pos(Line(I)) - Character'Pos('0');
         I := I + 1;
      end loop;

      while I <= Len and then Line(I) = ' ' loop
         I := I + 1;
      end loop;

      if Has_Digit and then (I > Len or else Line(I) = ',') then
         if I > Len then
            Position := 0;
         else
            Position := I + 1;
         end if;

         return Sign * Value;
      end if;

      Position := Start;

      declare
         Field : constant Field_Reference := Next_CSV_Field(Line, Position);
      begin
         return Parse_Integer_Field(Line, Field);
      end;
   end Parse_Next_Integer_Field;

   function Parse_Float_Field(
      Line : String;
      Field : Field_Reference) return Float is
      I : Natural := Field.First;
      Sign : Float := 1.0;
      Value : Float := 0.0;
      Scale : Float := 0.1;
      Exponent : Integer := 0;
      Exp_Sign : Integer := 1;
      Has_Digit : Boolean := False;
      Has_Exp_Digit : Boolean := False;
   begin
      if Field.Needs_Unescape then
         return Float'Value(Field_To_String(Line, Field));
      end if;

      while I <= Field.Last and then Line(I) = ' ' loop
         I := I + 1;
      end loop;

      if I <= Field.Last then
         if Line(I) = '-' then
            Sign := -1.0;
            I := I + 1;
         elsif Line(I) = '+' then
            I := I + 1;
         end if;
      end if;

      while I <= Field.Last and then Line(I) in '0' .. '9' loop
         Has_Digit := True;
         Value := Value * 10.0 +
            Float(Character'Pos(Line(I)) - Character'Pos('0'));
         I := I + 1;
      end loop;

      if I <= Field.Last and then Line(I) = '.' then
         I := I + 1;

         while I <= Field.Last and then Line(I) in '0' .. '9' loop
            Has_Digit := True;
            Value := Value +
               Scale * Float(Character'Pos(Line(I)) - Character'Pos('0'));
            Scale := Scale * 0.1;
            I := I + 1;
         end loop;
      end if;

      if I <= Field.Last
        and then (Line(I) = 'e' or else Line(I) = 'E')
      then
         I := I + 1;

         if I <= Field.Last then
            if Line(I) = '-' then
               Exp_Sign := -1;
               I := I + 1;
            elsif Line(I) = '+' then
               I := I + 1;
            end if;
         end if;

         while I <= Field.Last and then Line(I) in '0' .. '9' loop
            Has_Exp_Digit := True;
            Exponent := Exponent * 10 +
               Character'Pos(Line(I)) - Character'Pos('0');
            I := I + 1;
         end loop;

         if not Has_Exp_Digit then
            return Float'Value(Field_To_String(Line, Field));
         end if;
      end if;

      while I <= Field.Last and then Line(I) = ' ' loop
         I := I + 1;
      end loop;

      if Has_Digit and then I > Field.Last then
         if Exponent /= 0 then
            Value := Value * (10.0 ** (Exp_Sign * Exponent));
         end if;

         return Sign * Value;
      end if;

      return Float'Value(Field_To_String(Line, Field));
   end Parse_Float_Field;

   function Parse_Next_Float_Field(
      Line : String;
      Position : in out Natural) return Float is
      Len : constant Natural := Line'Length;
      Start : constant Natural := Position;
      I : Natural := Position;
      Sign : Float := 1.0;
      Value : Float := 0.0;
      Scale : Float := 0.1;
      Exponent : Integer := 0;
      Exp_Sign : Integer := 1;
      Has_Digit : Boolean := False;
      Has_Exp_Digit : Boolean := False;
   begin
      if Position = 0 then
         raise Constraint_Error;
      end if;

      if I <= Len and then Line(I) = '"' then
         declare
            Field : constant Field_Reference := Next_CSV_Field(Line, Position);
         begin
            return Parse_Float_Field(Line, Field);
         end;
      end if;

      while I <= Len and then Line(I) = ' ' loop
         I := I + 1;
      end loop;

      if I <= Len then
         if Line(I) = '-' then
            Sign := -1.0;
            I := I + 1;
         elsif Line(I) = '+' then
            I := I + 1;
         end if;
      end if;

      while I <= Len and then Line(I) in '0' .. '9' loop
         Has_Digit := True;
         Value := Value * 10.0 +
            Float(Character'Pos(Line(I)) - Character'Pos('0'));
         I := I + 1;
      end loop;

      if I <= Len and then Line(I) = '.' then
         I := I + 1;

         while I <= Len and then Line(I) in '0' .. '9' loop
            Has_Digit := True;
            Value := Value +
               Scale * Float(Character'Pos(Line(I)) - Character'Pos('0'));
            Scale := Scale * 0.1;
            I := I + 1;
         end loop;
      end if;

      if I <= Len and then (Line(I) = 'e' or else Line(I) = 'E') then
         I := I + 1;

         if I <= Len then
            if Line(I) = '-' then
               Exp_Sign := -1;
               I := I + 1;
            elsif Line(I) = '+' then
               I := I + 1;
            end if;
         end if;

         while I <= Len and then Line(I) in '0' .. '9' loop
            Has_Exp_Digit := True;
            Exponent := Exponent * 10 +
               Character'Pos(Line(I)) - Character'Pos('0');
            I := I + 1;
         end loop;

         if not Has_Exp_Digit then
            Position := Start;

            declare
               Field : constant Field_Reference := Next_CSV_Field(Line, Position);
            begin
               return Parse_Float_Field(Line, Field);
            end;
         end if;
      end if;

      while I <= Len and then Line(I) = ' ' loop
         I := I + 1;
      end loop;

      if Has_Digit and then (I > Len or else Line(I) = ',') then
         if Exponent /= 0 then
            Value := Value * (10.0 ** (Exp_Sign * Exponent));
         end if;

         if I > Len then
            Position := 0;
         else
            Position := I + 1;
         end if;

         return Sign * Value;
      end if;

      Position := Start;

      declare
         Field : constant Field_Reference := Next_CSV_Field(Line, Position);
      begin
         return Parse_Float_Field(Line, Field);
      end;
   end Parse_Next_Float_Field;

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
      Ensure_Column_Capacity(Result, DF.Num_Cols);
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

   procedure Load_CSV(File_Path : String;
                      DF : in out DataFrame_Type;
                      Headers : in Boolean := True) is
      File : File_Type;
      Line : Unbounded_String := Null_Unbounded_String;
      Expected_Rows : Natural := 0;
      Row_Capacity : Positive := 1;
      Header_Count : Natural := 0;
      Row_Num : Natural := 0;
      First_Row : Boolean := True;

      type Row_Job is record
         Stop : Boolean := False;
         Row : Natural := 0;
         Line : Unbounded_String := Null_Unbounded_String;
      end record;

      type Row_Job_Array is array (Positive range <>) of Row_Job;

      protected type Parser_Error is
         procedure Record_Error(Message : String);
         function Has_Error return Boolean;
         function Message return String;
      private
         Has_Value : Boolean := False;
         Text : Unbounded_String := Null_Unbounded_String;
      end Parser_Error;

      protected body Parser_Error is
         procedure Record_Error(Message : String) is
         begin
            if not Has_Value then
               Has_Value := True;
               Text := To_Unbounded_String(Message);
            end if;
         end Record_Error;

         function Has_Error return Boolean is
         begin
            return Has_Value;
         end Has_Error;

         function Message return String is
         begin
            return To_String(Text);
         end Message;
      end Parser_Error;

      protected type Row_Queue(Capacity : Positive) is
         entry Push(
            Row : Positive;
            Line : Unbounded_String;
            Accepted : out Boolean);
         entry Pop(Job : out Row_Job);
         procedure Finish(Abort_Now : Boolean := False);
      private
         Buffer : Row_Job_Array(1 .. Capacity);
         Head : Positive := 1;
         Tail : Positive := 1;
         Count : Natural := 0;
         Done : Boolean := False;
         Abort_Load : Boolean := False;
      end Row_Queue;

      protected body Row_Queue is
         entry Push(
            Row : Positive;
            Line : Unbounded_String;
            Accepted : out Boolean)
            when Count < Capacity or Done or Abort_Load
         is
         begin
            if Done or Abort_Load then
               Accepted := False;
               return;
            end if;

            Buffer(Tail).Stop := False;
            Buffer(Tail).Row := Row;
            Buffer(Tail).Line := Line;

            if Tail = Capacity then
               Tail := 1;
            else
               Tail := Tail + 1;
            end if;

            Count := Count + 1;
            Accepted := True;
         end Push;

         entry Pop(Job : out Row_Job)
            when Count > 0 or Done or Abort_Load
         is
         begin
            if Abort_Load or else (Done and Count = 0) then
               Job := (Stop => True, Row => 0, Line => Null_Unbounded_String);
               return;
            end if;

            Job := Buffer(Head);
            Buffer(Head) :=
               (Stop => False, Row => 0, Line => Null_Unbounded_String);

            if Head = Capacity then
               Head := 1;
            else
               Head := Head + 1;
            end if;

            Count := Count - 1;
         end Pop;

         procedure Finish(Abort_Now : Boolean := False) is
         begin
            Done := True;

            if Abort_Now then
               Abort_Load := True;
               for I in Buffer'Range loop
                  Buffer(I) :=
                     (Stop => False, Row => 0, Line => Null_Unbounded_String);
               end loop;
               Count := 0;
            end if;
         end Finish;
      end Row_Queue;

      Error_State : Parser_Error;

      procedure Parse_Header(Line_View : String) is
         Position : Natural := 1;
      begin
         Header_Count := CSV_Field_Count(Line_View);

         Ensure_Column_Capacity(DF, Header_Count);
         DF.Num_Cols := Header_Count;

         for I in 1 .. Header_Count loop
            declare
               Field : constant Field_Reference :=
                  Next_CSV_Field(Line_View, Position);
            begin
               if not Field.Found then
                  raise CSV_Error with "CSV header has too few columns";
               end if;

               DF.Column_Names(I) :=
                 To_Unbounded_String(Field_To_String(Line_View, Field));
            end;
         end loop;
      end Parse_Header;

      procedure Generate_Header(Line_View : String) is
      begin
         Header_Count := CSV_Field_Count(Line_View);

         Ensure_Column_Capacity(DF, Header_Count);
         DF.Num_Cols := Header_Count;

         for I in 1 .. Header_Count loop
            DF.Column_Names(I) :=
               To_Unbounded_String("column_" & Trim(Natural'Image(I), Both));
         end loop;
      end Generate_Header;

      procedure Initialize_Data_Row(
         Line_View : String;
         Row : Positive) is
         Position : Natural := 1;
      begin
         for Col in 1 .. DF.Num_Cols loop
            declare
               Field : constant Field_Reference :=
                  Next_CSV_Field(Line_View, Position);
            begin
               if not Field.Found then
                  raise CSV_Error with
                     "CSV row" & Natural'Image(Row) & " has too few columns";
               end if;

               declare
                  Field_Value : constant String :=
                     Field_To_String(Line_View, Field);
                  Val : constant Gusjo.Data.Value_Type :=
                     Gusjo.Data.Parse_Value(Field_Value);
               begin
                  case Val.Kind is
                     when Gusjo.Data.Integer_Type =>
                        DF.Columns(Col).Kind := Gusjo.Data.Integer_Type;
                        DF.Columns(Col).Int_Col :=
                           new Integer_Column.Column_Type(Row_Capacity);
                        Integer_Column.Set_At_Index(
                           DF.Columns(Col).Int_Col.all,
                           Gusjo.Data.To_Integer(Val),
                           Row);
                     when Gusjo.Data.Float_Type =>
                        DF.Columns(Col).Kind := Gusjo.Data.Float_Type;
                        DF.Columns(Col).Float_Col :=
                           new Float_Column.Column_Type(Row_Capacity);
                        Float_Column.Set_At_Index(
                           DF.Columns(Col).Float_Col.all,
                           Gusjo.Data.To_Float(Val),
                           Row);
                     when Gusjo.Data.String_Type =>
                        DF.Columns(Col).Kind := Gusjo.Data.String_Type;
                        DF.Columns(Col).String_Col :=
                           new String_Column.Column_Type(Row_Capacity);
                        String_Column.Set_At_Index(
                           DF.Columns(Col).String_Col.all,
                           To_Unbounded_String(Trim(Field_Value, Both)),
                           Row);
                  end case;
               end;
            end;
         end loop;

         if Position /= 0 then
            raise CSV_Error with
               "CSV row" & Natural'Image(Row) & " has too many columns";
         end if;
      end Initialize_Data_Row;

      procedure Parse_Known_Data_Row(
         Line_View : String;
         Row : Positive) is
         Position : Natural := 1;
      begin
         for Col in 1 .. DF.Num_Cols loop
            if Position = 0 then
               raise CSV_Error with
                  "CSV row" & Natural'Image(Row) & " has too few columns";
            end if;

            case DF.Columns(Col).Kind is
               when Gusjo.Data.Integer_Type =>
                  Integer_Column.Set_Preallocated_At_Index(
                     DF.Columns(Col).Int_Col.all,
                     Parse_Next_Integer_Field(Line_View, Position),
                     Row);
               when Gusjo.Data.Float_Type =>
                  Float_Column.Set_Preallocated_At_Index(
                     DF.Columns(Col).Float_Col.all,
                     Parse_Next_Float_Field(Line_View, Position),
                     Row);
               when Gusjo.Data.String_Type =>
                  declare
                     Field : constant Field_Reference :=
                        Next_CSV_Field(Line_View, Position);
                  begin
                     if not Field.Found then
                        raise CSV_Error with
                           "CSV row" & Natural'Image(Row) &
                           " has too few columns";
                     end if;

                     String_Column.Set_Preallocated_At_Index(
                        DF.Columns(Col).String_Col.all,
                        To_Unbounded_String(
                           Trim(Field_To_String(Line_View, Field), Both)),
                        Row);
                  end;
            end case;
         end loop;

         if Position /= 0 then
            raise CSV_Error with
               "CSV row" & Natural'Image(Row) & " has too many columns";
         end if;
      end Parse_Known_Data_Row;

      procedure Process_Line_View(Line : Unbounded_String; Row : Positive) is
         Line_Data : Ada.Strings.Unbounded.Aux.Big_String_Access;
         Line_Length : Natural;
      begin
         Ada.Strings.Unbounded.Aux.Get_String(Line, Line_Data, Line_Length);

         if Line_Length > 0 then
            declare
               Line_View : String renames Line_Data.all(1 .. Line_Length);
            begin
               Parse_Known_Data_Row(Line_View, Row);
            end;
         end if;
      end Process_Line_View;
   begin
      Delete(DF);

      Expected_Rows := Count_CSV_Data_Rows(File_Path, Headers);
      Row_Capacity := Positive(Natural'Max(1, Expected_Rows));

      Open(File, In_File, File_Path);

      while Row_Num = 0 and then not End_Of_File(File) loop
         Ada.Strings.Unbounded.Text_IO.Get_Line(File, Line);

         declare
            Line_Data : Ada.Strings.Unbounded.Aux.Big_String_Access;
            Line_Length : Natural;
         begin
            Ada.Strings.Unbounded.Aux.Get_String(Line, Line_Data, Line_Length);

            if Line_Length > 0 then
               declare
                  Line_View : String renames Line_Data.all(1 .. Line_Length);
               begin
                  if First_Row and then Headers then
                     Parse_Header(Line_View);
                     First_Row := False;
                  else
                     if First_Row then
                        Generate_Header(Line_View);
                        First_Row := False;
                     end if;

                     Row_Num := Row_Num + 1;
                     Initialize_Data_Row(Line_View, Row_Num);

                     if Expected_Rows > 1 then
                        Set_Column_Row_Counts(DF, Row_Capacity);
                     end if;
                  end if;
               end;
            end if;
         end;
      end loop;

      if Row_Num = 1 and then Expected_Rows > 1 then
         declare
            Worker_Count : constant Positive := CSV_Worker_Count;
            Queue_Capacity : constant Positive :=
               Positive'Max(1, Worker_Count * 2);
            Queue : Row_Queue(Queue_Capacity);

            task type CSV_Worker;

            task body CSV_Worker is
               Job : Row_Job;
            begin
               loop
                  Queue.Pop(Job);
                  exit when Job.Stop;

                  begin
                     Process_Line_View(Job.Line, Positive(Job.Row));
                     Job.Line := Null_Unbounded_String;
                  exception
                     when E : others =>
                        Job.Line := Null_Unbounded_String;
                        Error_State.Record_Error(Ada.Exceptions.Exception_Message(E));
                        Queue.Finish(Abort_Now => True);
                  end;
               end loop;
            end CSV_Worker;

            Workers : array (1 .. Worker_Count) of CSV_Worker;
         begin
            begin
               while not End_Of_File(File) loop
                  Ada.Strings.Unbounded.Text_IO.Get_Line(File, Line);

                  if Length(Line) > 0 then
                     declare
                        Accepted : Boolean;
                     begin
                        Row_Num := Row_Num + 1;

                        if Row_Num > Row_Capacity then
                           raise CSV_Error with
                              "CSV row count changed while loading";
                        end if;

                        Queue.Push(Row_Num, Line, Accepted);
                        exit when not Accepted or else Error_State.Has_Error;
                     end;
                  end if;
               end loop;

               Queue.Finish;
            exception
               when others =>
                  Queue.Finish(Abort_Now => True);
                  raise;
            end;
         end;

         if Error_State.Has_Error then
            raise CSV_Error with Error_State.Message;
         end if;
      end if;

      Close(File);
      DF.Num_Rows := Row_Num;
      Set_Column_Row_Counts(DF, Row_Num);
   exception
      when Name_Error =>
         raise CSV_Error with "File not found: " & File_Path;
      when CSV_Error =>
         if Is_Open(File) then
            Close(File);
         end if;
         Delete(DF);
         raise;
      when others =>
         if Is_Open(File) then
            Close(File);
         end if;
         Delete(DF);
         raise CSV_Error with "Error reading CSV file";
   end Load_CSV;

   procedure Display(
      DF : in DataFrame_Type;
      Max_Rows_Display : Natural := 10;
      Max_Width : Natural := 0) is
      Rows_To_Show : constant Natural :=
         Natural'Min(Max_Rows_Display, DF.Num_Rows);

      Separator : constant String := ", ";
      Ellipsis : constant String := "...";
      Minimum_Display_Width : constant Natural := 20;

      function Effective_Display_Width return Natural is
      begin
         if Max_Width > 0 then
            return Natural'Max(Minimum_Display_Width, Max_Width);
         end if;

         if Ada.Environment_Variables.Exists("COLUMNS") then
            declare
               Value : constant String :=
                  Trim(Ada.Environment_Variables.Value("COLUMNS"), Both);
            begin
               return Natural'Max(Minimum_Display_Width, Natural'Value(Value));
            exception
               when Constraint_Error =>
                  null;
            end;
         end if;

         return 80;
      end Effective_Display_Width;

      function Cell_Image(Row : Positive; Col : Positive) return String is
      begin
         case DF.Columns(Col).Kind is
            when Gusjo.Data.Integer_Type =>
               return Integer_Column.Get(DF.Columns(Col).Int_Col.all, Row)'Image;
            when Gusjo.Data.Float_Type =>
               return Float_Column.Get(DF.Columns(Col).Float_Col.all, Row)'Image;
            when Gusjo.Data.String_Type =>
               return To_String(String_Column.Get(DF.Columns(Col).String_Col.all, Row));
         end case;
      end Cell_Image;
   begin
      if DF.Num_Cols = 0 then
         Put_Line("(empty dataframe)");
         return;
      end if;

      declare
         type Column_Width_Array is array (Positive range <>) of Natural;

         Column_Widths : Column_Width_Array(1 .. DF.Num_Cols);
         Display_Width : constant Natural := Effective_Display_Width;

         function Full_Line_Length return Natural is
            Result : Natural := 0;
         begin
            for Col in 1 .. DF.Num_Cols loop
               if Col > 1 then
                  Result := Result + Separator'Length;
               end if;

               Result := Result + Column_Widths(Col);
            end loop;

            return Result;
         end Full_Line_Length;

         function Truncated_Line_Length(
            Left_Count : Natural;
            Right_Count : Natural) return Natural is
            Result : Natural := 0;
            Parts : Natural := 0;

            procedure Add_Part(Width : Natural) is
            begin
               if Parts > 0 then
                  Result := Result + Separator'Length;
               end if;

               Result := Result + Width;
               Parts := Parts + 1;
            end Add_Part;
         begin
            for Col in 1 .. Left_Count loop
               Add_Part(Column_Widths(Col));
            end loop;

            Add_Part(Ellipsis'Length);

            if Right_Count > 0 then
               for Col in DF.Num_Cols - Right_Count + 1 .. DF.Num_Cols loop
                  Add_Part(Column_Widths(Col));
               end loop;
            end if;

            return Result;
         end Truncated_Line_Length;

         procedure Put_Separator(Parts : in out Natural) is
         begin
            if Parts > 0 then
               Put(Separator);
            end if;

            Parts := Parts + 1;
         end Put_Separator;

         procedure Put_Header(
            Show_All : Boolean;
            Left_Count : Natural;
            Right_Count : Natural) is
            Parts : Natural := 0;

            procedure Put_Name(Col : Positive) is
            begin
               Put_Separator(Parts);
               Put(To_String(DF.Column_Names(Col)));
            end Put_Name;
         begin
            if Show_All then
               for Col in 1 .. DF.Num_Cols loop
                  Put_Name(Col);
               end loop;
            else
               for Col in 1 .. Left_Count loop
                  Put_Name(Col);
               end loop;

               Put_Separator(Parts);
               Put(Ellipsis);

               if Right_Count > 0 then
                  for Col in DF.Num_Cols - Right_Count + 1 .. DF.Num_Cols loop
                     Put_Name(Col);
                  end loop;
               end if;
            end if;

            New_Line;
         end Put_Header;

         procedure Put_Row(
            Row : Positive;
            Show_All : Boolean;
            Left_Count : Natural;
            Right_Count : Natural) is
            Parts : Natural := 0;

            procedure Put_Cell(Col : Positive) is
            begin
               Put_Separator(Parts);
               Put(Cell_Image(Row, Col));
            end Put_Cell;
         begin
            if Show_All then
               for Col in 1 .. DF.Num_Cols loop
                  Put_Cell(Col);
               end loop;
            else
               for Col in 1 .. Left_Count loop
                  Put_Cell(Col);
               end loop;

               Put_Separator(Parts);
               Put(Ellipsis);

               if Right_Count > 0 then
                  for Col in DF.Num_Cols - Right_Count + 1 .. DF.Num_Cols loop
                     Put_Cell(Col);
                  end loop;
               end if;
            end if;

            New_Line;
         end Put_Row;

         Show_All : Boolean;
         Left_Count : Natural := 1;
         Right_Count : Natural := 1;
      begin
         for Col in 1 .. DF.Num_Cols loop
            declare
               Name : constant String := To_String(DF.Column_Names(Col));
            begin
               Column_Widths(Col) := Name'Length;
            end;
         end loop;

         for Row in 1 .. Rows_To_Show loop
            for Col in 1 .. DF.Num_Cols loop
               declare
                  Value : constant String := Cell_Image(Row, Col);
               begin
                  Column_Widths(Col) :=
                     Natural'Max(Column_Widths(Col), Value'Length);
               end;
            end loop;
         end loop;

         Show_All := DF.Num_Cols <= 2
            or else Full_Line_Length <= Display_Width;

         if not Show_All then
            while Left_Count + Right_Count < DF.Num_Cols - 1 loop
               declare
                  Prefer_Left : constant Boolean := Left_Count <= Right_Count;
                  Can_Add_Left : constant Boolean :=
                     Left_Count + Right_Count < DF.Num_Cols - 1;
                  Can_Add_Right : constant Boolean := Can_Add_Left;
                  Added : Boolean := False;

                  procedure Try_Add_Left is
                  begin
                     if Can_Add_Left
                       and then Truncated_Line_Length(
                          Left_Count + 1,
                          Right_Count) <= Display_Width
                     then
                        Left_Count := Left_Count + 1;
                        Added := True;
                     end if;
                  end Try_Add_Left;

                  procedure Try_Add_Right is
                  begin
                     if Can_Add_Right
                       and then Truncated_Line_Length(
                          Left_Count,
                          Right_Count + 1) <= Display_Width
                     then
                        Right_Count := Right_Count + 1;
                        Added := True;
                     end if;
                  end Try_Add_Right;
               begin
                  if Prefer_Left then
                     Try_Add_Left;
                     if not Added then
                        Try_Add_Right;
                     end if;
                  else
                     Try_Add_Right;
                     if not Added then
                        Try_Add_Left;
                     end if;
                  end if;

                  exit when not Added;
               end;
            end loop;
         end if;

         Put_Header(Show_All, Left_Count, Right_Count);

         --  Print rows
         for Row in 1 .. Rows_To_Show loop
            Put_Row(Row, Show_All, Left_Count, Right_Count);
         end loop;

         if not Show_All then
            Put_Line(
               "... (" &
               Natural'Image(DF.Num_Cols - Left_Count - Right_Count) &
               " more columns)");
         end if;
      end;

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

   procedure Delete(DF : in out DataFrame_Type) is
   begin
      if DF.Columns /= null then
         for Col in 1 .. DF.Num_Cols loop
            Free_Column(DF.Columns(Col));
         end loop;

         Free_Column_Refs(DF.Columns);
      end if;

      if DF.Column_Names /= null then
         Free_Column_Names(DF.Column_Names);
      end if;

      DF.Num_Rows := 0;
      DF.Num_Cols := 0;
      DF.Capacity_Cols := 0;
   end Delete;

end Gusjo.Data.Frame;
