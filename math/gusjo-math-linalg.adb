with Ada.Integer_Text_IO;        use Ada.Integer_Text_IO;
with Ada.Float_Text_IO;          use Ada.Float_Text_IO;

with Ada.Environment_Variables;
with Ada.Unchecked_Deallocation;
with Ada.Numerics.Float_Random;
with Ada.Strings;
with Ada.Strings.Fixed;
with System.Multiprocessors;

with Ada.Numerics.Elementary_Functions;   use Ada.Numerics.Elementary_Functions;

package body Gusjo.Math.Linalg is

   Parallel_Matmul_Min_Ops : constant Long_Long_Integer := 1_000_000;
   
   procedure Free is new Ada.Unchecked_Deallocation(Matrix_Type, Matrix);
   
   procedure Free is new Ada.Unchecked_Deallocation(Matrix_Type, Row_Vector);
   
   procedure Free is new Ada.Unchecked_Deallocation(Matrix_Type, Column_Vector);

   function Matmul_Worker_Count return Positive is
      Default_Count : constant Positive :=
         Positive(System.Multiprocessors.Number_Of_CPUs);
   begin
      if Ada.Environment_Variables.Exists("GUSJO_MATMUL_WORKERS") then
         declare
            Value : constant String :=
               Ada.Strings.Fixed.Trim(
                  Ada.Environment_Variables.Value("GUSJO_MATMUL_WORKERS"),
                  Ada.Strings.Both);
            Parsed : constant Positive := Positive'Value(Value);
         begin
            return Parsed;
         exception
            when Constraint_Error =>
               null;
         end;
      end if;

      return Default_Count;
   end Matmul_Worker_Count;
   
   procedure Delete(Item : in out Matrix) is
   begin
      if item /= null then
         Free(Item);
      end if;
   end Delete;
   
   procedure Delete(Item : in out Row_Vector) is
   begin
      if item /= null then
         Free(Item);
      end if;
   end Delete;
   
   procedure Delete(Item : in out Column_Vector) is
   begin
      if item /= null then
         Free(Item);
      end if;
   end Delete;

   procedure Set_To_Null(Item : in out Matrix) is
   begin
      Item := null;
   end Set_To_Null;
   
   procedure Set_To_Null(Item : in out Row_Vector) is
   begin
      Item := null;
   end Set_To_Null;
   
   procedure Set_To_Null(Item : in out Column_Vector) is
   begin
      Item := null;
   end Set_To_Null;
   
   procedure Null_Check(Item : in Matrix) is
   begin
      if Item = null then
	 raise Null_Pointer_Exception with "Matrix is null";
      end if;
   end Null_Check;
   
   procedure Null_Check(Item : in Row_Vector) is
   begin
      if Item = null then
	 raise Null_Pointer_Exception with "Matrix is null";
      end if;
   end Null_Check;
   
   procedure Null_Check(Item : in Column_Vector) is
   begin
      if Item = null then
	 raise Null_Pointer_Exception with "Matrix is null";
      end if;
   end Null_Check;
   
   procedure Square_Check(Item : in Matrix) is
   begin
      if Item'Last(1) /= Item'Last(2) then
	 raise Dimension_Error with "Matrix must be square";
      end if;
   end Square_Check;
   
   procedure Same_Dimension(Left, Right: in Matrix) is
   begin
      if Rows(Left) /= Rows(Right) or Cols(Left) /= Cols(Right) then
	 raise Dimension_Error with "Matrixes must have the same dimension";
      end if;
   end Same_Dimension;
   
   ------------------ Get/Put Matrix ------------------
   
   procedure Get(File : in File_Type;
		 Item : in out Matrix;
		 N, M : in Integer) is
   begin
      if Item /= null then
      	 Delete(Item);
      end if;
      
      Item := new Matrix_Type(1..N, 1..M);
      
      for I in Item'Range(1) loop
	 for J in Item'Range(2) loop
	    Get(File, Item(I, J));
	 end loop;
      end loop;
      
   end Get;
   
   
   procedure Get(File : in File_Type;
		 Item : in out Matrix) is
      N, M : Integer;
   begin
      Get(File, N);
      Get(File, M);
      Skip_Line(File);

      Get(File, Item, N, M);
   end Get;
   
   procedure Get(Item : in out Matrix;
		 N, M : in Integer) is
   begin
      Get(Standard_Input, Item, N, M);
   end Get;
   
   procedure Get(Item : in out Matrix) is
   begin
      Get(Standard_Input, Item);
   end Get;
   
   
   procedure Put(File : in File_Type;
		 Item : in Matrix;
		 Fore : in Integer := 5;
		 Aft  : in Integer := 5;
		 Exp  : in Integer := 0) is
   begin
      Null_Check(Item);
      Put(File, Item'Length(1), Width => Fore);
      Put(File, ' ');
      Put(File, Item'Length(2), Width => Fore);
      New_Line(File);

      for I in Item'Range(1) loop
         for J in Item'Range(2) loop
            if J > Item'First(2) then
               Put (File, ' ');
            end if;
            Put(File, Item(I, J), Fore => Fore, Aft => Aft, Exp => Exp);
         end loop;
      New_Line(File);
      end loop;
   end Put;
   
   procedure Put(Item : in Matrix;
		 Fore : in Integer := 5;
		 Aft  : in Integer := 5;
		 Exp  : in Integer := 0) is
   begin
      Put(Standard_Output, Item, Fore, Aft, Exp);
   end Put;
   
   ------------------ Get/Put Row_Vector ------------------
   
   procedure Get(File : in File_Type;
		 Item : in out Row_Vector;
		 M   : in Integer) is
   begin
      if Item /= null then
      	 Delete(Item);
      end if;
      
      Item := new Matrix_Type(1..1, 1..M);
      
      for I in Item'Range(1) loop
         for J in Item'Range(2) loop
            Get(File, Item(I, J));
         end loop;
      end loop;
      
   end Get;
   
   procedure Get(File : in File_Type;
		 Item : in out Row_Vector) is
      M : Integer;
   begin
      Get(File, M);
      Put_Line("M:" & M'Image);
      
      Get(File, Item, M);
      
   end Get;
   
   procedure Get(Item : in out Row_Vector;
		 M    : in Integer) is
   begin
      Get(Standard_Input, Item, M);
   end Get;
   
   procedure Get(Item : in out Row_Vector) is
   begin
      Get(Standard_Input, Item);
   end Get;
   
   procedure Put(File : in File_Type;
		 Item : in Row_Vector;
		 Fore : in Integer := 5;
		 Aft  : in Integer := 5;
		 Exp  : in Integer := 0) is
   begin
      Null_Check(Item);
      for I in Item'Range(1) loop
	 for J in Item'Range(2) loop
	    Put(File, Item(I, J), Fore => Fore, Aft => Aft, Exp => Exp);
	 end loop;
	 New_Line(File);
      end loop;
   end Put;
   
   procedure Put(Item : in Row_Vector;
		 Fore : in Integer := 5;
		 Aft  : in Integer := 5;
		 Exp  : in Integer := 0) is
   begin
      Put(Standard_Output, Item, Fore, Aft, Exp);
   end Put;
   
   ------------------ Get/Put Col_Vector ------------------
   
   procedure Get(File : in File_Type;
		 Item : in out Column_Vector;
		 N    : in Integer) is
   begin
      if Item /= null then
      	 Delete(Item);
      end if;
      
      Item := new Matrix_Type(1..N, 1..1);
      
      for I in Item'Range(1) loop
	 for J in Item'Range(2) loop
	    Get(File, Item(I, J));
	 end loop;
      end loop;
      
   end Get;
   
   procedure Get(File : in File_Type;
		 Item : in out Column_Vector) is
      N: Integer;
   begin
      Get(File, N);
      
      Put_Line("N:" & N'Image);
      
      Get(File, Item, N);
      
   end Get;
   
   procedure Get(Item : in out Column_Vector;
		 N    : in Integer) is
   begin
      Get(Standard_Input, Item, N);
   end Get;
   
   procedure Get(Item : in out Column_Vector) is
   begin
      Get(Standard_Input, Item);
   end Get;
   
   procedure Put(File : in File_Type;
		 Item : in Column_Vector;
		 Fore : in Integer := 5;
		 Aft  : in Integer := 5;
		 Exp  : in Integer := 0) is
   begin
      Null_Check(Item);
      for I in Item'Range(1) loop
         for J in Item'Range(2) loop
            Put(File, Item(I, J), Fore => Fore, Aft => Aft, Exp => Exp);
         end loop;
      New_Line(File);
      end loop;
   end Put;
   
   procedure Put(Item : in Column_Vector;
		 Fore : in Integer := 5;
		 Aft  : in Integer := 5;
		 Exp  : in Integer := 0) is
   begin
      Put(Standard_Output, Item, Fore, Aft, Exp);
   end Put;
   
   ------------------ CREATORS ------------------
   
   function Transpose(Item : in Matrix) return Matrix is
      Result : Matrix;
   begin
      Null_Check(Item);
      
      Result := new Matrix_Type(Item'Range(2), Item'Range(1));
      
      for I in Item'Range(1) loop
	      for J in Item'Range(2) loop
	         Result(J, I) := Item(I, J);
   	   end loop;
      end loop;
      
      return Result;
   end Transpose;
   
   
   function Identity_Matrix(N : in Positive) return Matrix is
      Result : Matrix;
   begin
      Result := new Matrix_Type(1..N, 1..N);
      
      for I in 1..N loop
	 Result(I, I) := 1.0;
      end loop;
      return Result;
   end Identity_Matrix;

   procedure Fill_Random_Uniform(V : in out Column_Vector; Low, High : in Float) is
      Gen : Ada.Numerics.Float_Random.Generator;
      Rng : constant Float := High - Low;
   begin
      Null_Check(V);
      Ada.Numerics.Float_Random.Reset(Gen);
      for I in V'Range(1) loop
         V(I, 1) := Low + Rng * Ada.Numerics.Float_Random.Random(Gen);
      end loop;
   end Fill_Random_Uniform;

   procedure Fill_Random_Uniform(M           : in out Matrix;
                                 Low, High   : in     Float) is
      Gen : Ada.Numerics.Float_Random.Generator;
      Rng : constant Float := High - Low;
   begin
      Null_Check(M);
      Ada.Numerics.Float_Random.Reset(Gen);
      for I in M'Range(1) loop
         for II in M'Range(2) loop
            M(I, II) := Low + Rng * Ada.Numerics.Float_Random.Random(Gen);
         end loop;
      end loop;
   end Fill_Random_Uniform;

   function Column1(X0 : Float) return Column_Vector is
      M : Matrix := Zeros(1, 1);
      R : Column_Vector;
   begin
      M(1, 1) := X0;
      R := To_Column_Vector(M);
      Delete(M);
      return R;
   end Column1;

   function Column2(X0, X1 : Float) return Column_Vector is
      M : Matrix := Zeros(2, 1);
      R : Column_Vector;
   begin
      M(1, 1) := X0;
      M(2, 1) := X1;
      R := To_Column_Vector(M);
      Delete(M);
      return R;
   end Column2;

   function Column3(X0, X1, X2 : Float) return Column_Vector is
      M : Matrix := Zeros(3, 1);
      R : Column_Vector;
   begin
      M(1, 1) := X0;
      M(2, 1) := X1;
      M(3, 1) := X2;
      R := To_Column_Vector(M);
      Delete(M);
      return R;
   end Column3;

   function Column_Vector_From_Array(Values : in Float_Array) return Column_Vector is
      M : Matrix := Zeros(Values'Length, 1);
      R : Column_Vector;
   begin
      for I in Values'Range loop
         M(I - Values'First + 1, 1) := Values(I);
      end loop;
      R := To_Column_Vector(M);
      Delete(M);
      return R;
   end Column_Vector_From_Array;

   function Row1(X0 : Float) return Row_Vector is
      M : Matrix := Zeros(1, 1);
      R : Row_Vector;
   begin
      M(1, 1) := X0;
      R := To_Row_Vector(M);
      Delete(M);
      return R;
   end Row1;

   function Row2(X0, X1 : Float) return Row_Vector is
      M : Matrix := Zeros(1, 2);
      R : Row_Vector;
   begin
      M(1, 1) := X0;
      M(1, 2) := X1;
      R := To_Row_Vector(M);
      Delete(M);
      return R;
   end Row2;

   function Row3(X0, X1, X2 : Float) return Row_Vector is
      M : Matrix := Zeros(1, 3);
      R : Row_Vector;
   begin
      M(1, 1) := X0;
      M(1, 2) := X1;
      M(1, 3) := X2;
      R := To_Row_Vector(M);
      Delete(M);
      return R;
   end Row3;

   function HStack_Columns(Vs : in Column_Vector_Array) return Matrix is
   begin
      if Vs'Length = 0 then
         raise Dimension_Error with "No vectors to stack";
      end if;

      -- Validate vectors and find common row count
      Null_Check (Vs (Vs'First));
      declare
         Rows_Count : constant Positive := Vs (Vs'First)'Length (1);
         B          : constant Positive := Vs'Length;
         R          : Matrix           := Zeros (Rows_Count, B);
         col        : Positive          := 1;
      begin
         -- Check all lengths match
         for k in Vs'First .. Vs'Last loop
            Null_Check (Vs (k));
            if Vs (k)'Length (1) /= Rows_Count then
               raise Dimension_Error with "HStack_Columns: all vectors must have same length";
            end if;
         end loop;

         -- Copy each vector into column 'col'
         for k in Vs'First .. Vs'Last loop
            for i in 1 .. Rows_Count loop
               R (i, col) := Vs (k) (i, 1);
            end loop;
            col := col + 1;
         end loop;

         return R;
      end;
   end HStack_Columns;

   function VStack_Rows(Rs : in Row_Vector_Array) return Matrix is
   begin
      if Rs'Length = 0 then
         raise Dimension_Error with "No vectors to stack";
      end if;

      -- Validate vectors and find common column count
      Null_Check (Rs (Rs'First));
      declare
         Cols_Count : constant Positive := Rs (Rs'First)'Length (2);
         B          : constant Positive := Rs'Length;
         R          : Matrix           := Zeros (B, Cols_Count);
         row        : Positive          := 1;
      begin
         -- Check all lengths match
         for k in Rs'First .. Rs'Last loop
            Null_Check (Rs (k));
            if Rs (k)'Length (2) /= Cols_Count then
               raise Dimension_Error with "VStack_Rows: all vectors must have same length";
            end if;
         end loop;

         -- Copy each vector into row 'row'
         for k in Rs'First .. Rs'Last loop
            for j in 1 .. Cols_Count loop
               R (row, j) := Rs (k) (1, j);
            end loop;
            row := row + 1;
         end loop;

         return R;
      end;
   end VStack_Rows;

   
   ----------------------------------------------------------------------------------
   
   function Matrix_With_Num(N, M : in Positive;
			    Value : in Float) return Matrix is
      Result : Matrix;
   begin
      Result := new Matrix_Type(1..N, 1..M);
      
      for I in 1..N loop
	 for J in 1..M loop
	    Result(I, J) := Value;
	 end loop;
      end loop;
      return Result;
   end Matrix_With_Num;
   
   function Matrix_With_Num(N : in Positive;
			    Value : in Float) return Matrix is
   begin
      return Matrix_With_Num(N, 1, Value);
   end Matrix_With_Num;
   
   function Zeros(N : in Positive) return Matrix is
   begin
      return Matrix_With_Num(N, 1, 0.0);
   end Zeros;
   
   function Zeros(N, M : in Positive) return Matrix is
   begin
      return Matrix_With_Num(N, M, 0.0);
   end Zeros;
   
   function Ones(N : in Positive) return Matrix is
   begin
      return Matrix_With_Num(N, 1, 1.0);
   end Ones;
   
   function Ones(N, M : in Positive) return Matrix is
   begin
      return Matrix_With_Num(N, M, 1.0);
   end Ones;
   
   ----------------------------------------------------------------------------------
   
   function Cols(Item : in Matrix) return Positive is
   begin
      Null_Check(Item);
      return Item'Last(2);
   end Cols;

   function Rows(Item : in Matrix) return Positive is
   begin
      Null_Check(Item);
      return Item'Last(1);
   end Rows;

   function Length(V : in Column_Vector) return Positive is
   begin
      Null_Check(V);
      return Positive(V'Length(1));
   end Length;

   function Length(V : in Row_Vector) return Positive is
   begin
      Null_Check(V);
      return Positive(V'Length(2));
   end Length;

   function Argmax(V : Column_Vector) return Positive is
      Best_I : Positive := V'First(1);
      Best_V : Float    := V(Best_I, 1);
   begin
      for I in V'First(1) + 1 .. V'Last(1) loop
         if V(I, 1) > Best_V then
            Best_V := V(I, 1);
            Best_I := I;
         end if;
      end loop;
      return Best_I;
   end;

   function Argmax_Columns(P : in Matrix) return Indices_Array is
   begin
      Null_Check (P);
      if Cols (P) = 0 then
         -- Return an empty index array
         declare
            Empty : Indices_Array (1 .. 0);
         begin
            return Empty;
         end;
      end if;

      declare
         B   : constant Positive      := Cols (P);
         Res : Indices_Array (1 .. B);
      begin
         for j in 1 .. B loop
            -- Initialize with first row of column j
            declare
               best_i : Positive := 1;
               best_v : Float    := P (1, j);
            begin
               for i in 2 .. Rows (P) loop
                  if P (i, j) > best_v then
                     best_v := P (i, j);
                     best_i := i;
                  end if;
               end loop;
               Res(j) := best_i;
            end;
         end loop;
         return Res;
      end;
   end Argmax_Columns;

   function CrossEntropy_OneHot(P, Y : Column_Vector) return Float is
      Eps : constant Float := 1.0E-7;
      CE  : Float := 0.0;
      Pi  : Float;
   begin
      for I in P'Range(1) loop
         if Y(I, 1) = 1.0 then
            Pi := Float'Max(Eps, Float'Min (1.0 - Eps, P (I, 1)));
            CE := -Log(Pi);
            return CE;
         end if;
      end loop;
      return 0.0; -- if Y isn't one-hot, you can extend to full sum
   end;

   function CrossEntropy_OneHot(P, Y : in Matrix) return Float is
      B    : constant Float := Float(Cols(P));  -- batch size
      Loss : Float := 0.0;
   begin
      Null_Check(P);
      Null_Check(Y);

      if Rows(P) /= Rows(Y) or else Cols(P) /= Cols(Y) then
         raise Dimension_Error with "P and Y must have same shape in CrossEntropy_OneHot";
      end if;

      for j in 1 .. Cols(P) loop
         for i in 1 .. Rows(P) loop
            if Y(i, j) = 1.0 then
               -- clip to avoid log(0)
               declare
                  p_clipped : constant Float :=
                  Float'Max(1.0E-7, Float'Min(1.0 - 1.0E-7, P(i, j)));
               begin
                  Loss := Loss - Log(p_clipped);
               end;
            end if;
         end loop;
      end loop;

      return Loss / B;
   end CrossEntropy_OneHot;
   
   ----------------------------------------------------------------------------------
   
   function Copy_Dimension(Item : in Matrix) return Matrix is
   begin
      return new Matrix_Type(Item'Range(1), Item'Range(2));
   end Copy_Dimension;
   
   function Copy_Dimension(Item : in Matrix) return Column_Vector is
   begin
      return new Matrix_Type(Item'Range(1), Item'Range(2));
   end Copy_Dimension;
   
   function Copy_Dimension(Item : in Matrix) return Row_Vector is
   begin
      return new Matrix_Type(Item'Range(1), Item'Range(2));
   end Copy_Dimension;
   
   function Copy_Dimension(Item : in Column_Vector) return Column_Vector is
   begin
      return new Matrix_Type(Item'Range(1), Item'Range(2));
   end Copy_Dimension;
   
   function Copy_Dimension(Item : in Row_Vector) return Row_Vector is
   begin
      return new Matrix_Type(Item'Range(1), Item'Range(2));
   end Copy_Dimension;
   
   function Copy_Dimension(Item : in Column_Vector) return Matrix is
   begin
      return new Matrix_Type(Item'Range(1), Item'Range(2));
   end Copy_Dimension;
   
   function Copy_Dimension(Item : in Row_Vector) return Matrix is
   begin
      return new Matrix_Type(Item'Range(1), Item'Range(2));
   end Copy_Dimension;
   
   ----------------------------------------------------------------------------------
   
   function "*"(Left, Right : in Matrix) return Matrix is
      Result : Matrix;
      Left_Rows     : Positive;
      Left_Cols     : Positive;
      Right_Cols    : Positive;
      Operation_Count : Long_Long_Integer;
   begin
      Null_Check(Left);
      Null_Check(Right);

      if Cols(Left) /= Rows(Right) then
	 raise Dimension_Error with "Number of collumns in left matrix must equal number of rows in right matrix";
      end if;

      Left_Rows := Rows(Left);
      Left_Cols := Cols(Left);
      Right_Cols := Cols(Right);
      Operation_Count :=
         Long_Long_Integer(Left_Rows) *
         Long_Long_Integer(Left_Cols) *
         Long_Long_Integer(Right_Cols);
      
      Result := new Matrix_Type(1..Left_Rows, 1..Right_Cols);
      
      declare
         procedure Multiply_Row(I : in Positive) is
            Sum : Float;
         begin
            for K in 1 .. Right_Cols loop
               Sum := 0.0;
               for J in 1 .. Left_Cols loop
                  Sum := Sum + Left(I, J) * Right(J, K);
               end loop;
               Result(I, K) := Sum;
            end loop;
         end Multiply_Row;

         procedure Multiply_Serial is
         begin
            for I in 1 .. Left_Rows loop
               Multiply_Row(I);
            end loop;
         end Multiply_Serial;

      begin
         if Operation_Count < Parallel_Matmul_Min_Ops then
            Multiply_Serial;
         else
            declare
               Worker_Count : constant Positive :=
                  Positive'Min(Matmul_Worker_Count, Left_Rows);
            begin
               if Worker_Count = 1 then
                  Multiply_Serial;
               else
                  declare
                     protected type Row_Dispenser is
                        procedure Next(Available : out Boolean;
                                       Row       : out Positive);
                     private
                        Next_Row : Natural := 1;
                     end Row_Dispenser;

                     protected body Row_Dispenser is
                        procedure Next(Available : out Boolean;
                                       Row       : out Positive) is
                        begin
                           if Next_Row <= Left_Rows then
                              Available := True;
                              Row := Next_Row;
                              Next_Row := Next_Row + 1;
                           else
                              Available := False;
                              Row := 1;
                           end if;
                        end Next;
                     end Row_Dispenser;

                     Rows_To_Process : Row_Dispenser;

                     task type Matmul_Worker;

                     task body Matmul_Worker is
                        Available : Boolean;
                        Row       : Positive;
                     begin
                        loop
                           Rows_To_Process.Next(Available, Row);
                           exit when not Available;
                           Multiply_Row(Row);
                        end loop;
                     end Matmul_Worker;

                     Workers : array (1 .. Worker_Count) of Matmul_Worker;
                  begin
                     null;
                  end;
               end if;
            end;
         end if;
      end;

      return Result;
      
   end "*";
   
   function "*"(Left  : in Matrix;
		Right : in Float) return Matrix is
      Result : Matrix;
   begin
      Null_Check(Left);
      
      Result := Copy_Dimension(Left);
      
      for I in Left'Range(1) loop
	 for J in Left'Range(2) loop
	    Result(I, J) := Left(I, J) * Right;
	 end loop;
      end loop;
      
      return Result;
      
   end "*";
   
   function "*"(Left  : in Float;
		Right : in Matrix) return Matrix is
   begin
      return Right * Left;
   end "*";
   
   function "*"(Left  : in Matrix;
		Right : in Integer) return Matrix is
   begin
      return Left * Float(Right);
   end "*";
   
   function "*"(Left  : in Integer;
		Right : in Matrix) return Matrix is
   begin
      return Float(Left) * Right;
   end "*";
   
   function "+"(Left, Right: in Matrix) return Matrix is
      Result : Matrix;
   begin
      Null_Check(Left);
      Null_Check(Right);
      Same_Dimension(Left, Right);
      
      Result := Copy_Dimension(Left);
      
      for I in Left'Range(1) loop
	 for J in Left'Range(2) loop
	    Result(I, J) := Left(I, J) + Right(I, J);
	 end loop;
      end loop;
      
      return Result;
   end "+";
   
   
   function "-"(Left, Right : in Matrix) return Matrix is
      Result : Matrix;
   begin
      Null_Check(Left);
      Null_Check(Right);
      Same_Dimension(Left, Right);
      
      Result := Copy_Dimension(Left);
      
      for I in Left'Range(1) loop
	 for J in Left'Range(2) loop
	    Result(I, J) := Left(I, J) - Right(I, J);
	 end loop;
      end loop;
      
      return Result;
   end "-";
   
   function Equals(Left, Right : in Matrix) return Boolean is
   begin
      Null_Check(Left);
      Null_Check(Right);
      
      begin
	 Same_Dimension(Left, Right);
      exception
	 when Dimension_Error =>
	    return False;
      end;
      
      for I in Left'Range(1) loop
	 for J in Left'Range(2) loop
	    if Left(I, J) /= Right(I, J) then
	       return False;
	    end if;
	 end loop;
      end loop;
      
      return True;
   end Equals;
   
   function Remove_Row(Item : in Matrix;
		       N    : in Positive) return Matrix is
      Result : Matrix;
   begin
      Result := new Matrix_Type(1..Rows(Item)-1, Item'Range(2));
      
      for I in Item'Range(1) loop
	 for J in Item'Range(2) loop
	    if I < N then
	       Result(I, J) := Item(I, J);
	    elsif I > N then
	       Result(I - 1 , J) := Item(I, J);
	    end if;
	 end loop;
      end loop;
      return Result;
   end Remove_Row;
   
   function Remove_Col(Item : in Matrix;
		       M    : in Positive) return Matrix is
      Result : Matrix;
   begin
      Result := new Matrix_Type(Item'Range(1), 1..Cols(Item)-1);
      
      for I in Item'Range(1) loop
	 for J in Item'Range(2) loop
	    if J < M then
	       Result(I, J) := Item(I, J);
	    elsif J > M then
	       Result(I , J - 1) := Item(I, J);
	    end if;
	 end loop;
      end loop;
      return Result;
   end Remove_Col;
   
   function Det(Item : in Matrix) return Float is
      Result  : Float   := 0.0;
      OddTurn : Boolean := True;
      Tmp1    : Matrix;
      Tmp2    : Matrix;
   begin
      Null_Check(Item);
      Square_Check(Item);
      
      if Item'Last(1) = 1 or Item'Last(2) = 1 then
   	 --raise Dimension_Error with "Trying to compute Determinant of a 1x1 matrix";
	 return Item(1, 1);
      end if;
      
      if Item'Last(1) = 2 and Item'Last(2) = 2 then
   	 Result := Item(1, 1) * Item(2, 2) - Item(1, 2) * Item(2, 1);
      else
   	 for J in Item'Range(2) loop
   	    Tmp1 := Remove_Row(Item, 1);
   	    Tmp2 := Remove_Col(Tmp1, J);
	    
   	    if OddTurn then
   	       Result := Result + Item(1, J) * Det(Tmp2);
   	    else
   	       Result := Result - Item(1, J) * Det(Tmp2);
   	    end if;
	    
   	    OddTurn := not OddTurn;
	    
   	    Free(Tmp1);
   	    Free(Tmp2);
	    
   	 end loop;
      end if;
      return Result;
   end Det;

   function Adjugate(Item : in Matrix) return Matrix is
      Result : Matrix;
      Minor_Matrix : Matrix;
      Cofactor_Matrix : Matrix;
      
      function OddEven(I, J : in Integer) return Float is
      begin
   	 if(I + J) mod 2 = 0 then
   	    return 1.0;
   	 else
   	    return-1.0;
   	 end if;
      end OddEven;
      
   begin
      Result := Copy_Dimension(Item);
      for I in Item'Range(1) loop
   	 for J in Item'Range(2) loop
   	    Minor_Matrix := Remove_Row(Item, I);
   	    Cofactor_Matrix := Remove_Col(Minor_Matrix, J);
	    
   	    Result(J, I) := OddEven(I, J) * Det(Cofactor_Matrix);
	    
   	    Free(Minor_Matrix);
   	    Free(Cofactor_Matrix);
   	 end loop;
      end loop;
      return Result;
   end Adjugate;
   
   function Inverse(Item : in Matrix) return Matrix is
      Result : Matrix;
   begin
      Null_Check(Item);
      Square_Check(Item);
      
      if Det(Item) = 0.0 then
   	 raise Invertion_Error with "Matrix is not invertible";
      end if;
      
      Result := Adjugate(Item);
      
      return (1.0 / Det(Item)) * Result;
   end Inverse;
   
   
   procedure Combine_Vertically(Top    : in out Matrix;
				Bottom : in Matrix) is
      Tmp : Matrix;
   begin
      Null_Check(Top);
      Null_Check(Bottom);
      if Cols(Top) /= Cols(Bottom) then
	 raise Dimension_Error with "Matrixes must have the same number of collumns.";
      end if;
      
      Tmp := new Matrix_Type(1 .. (Rows(Top) + Rows(Bottom)), 1 .. Cols(Top));
      
      for I in Top'Range(1) loop
	 for J in Top'Range(2) loop
	    Tmp(I, J) := Top(I, J);
	 end loop;
      end loop;
      
      for I in Bottom'Range(1) loop
	 for J in Bottom'Range(2) loop
	    Tmp(I + Rows(Top), J) := Bottom(I, J);
	 end loop;
      end loop;
      
      Free(Top);
      
      Top := Tmp;
   end;
   
   procedure Combine_Horizontally(Left  : in out Matrix;
				  Right : in Matrix) is
      Tmp : Matrix;
   begin
      Null_Check(Left);
      Null_Check(Right);
      if Rows(Left) /= Rows(Right) then
	 raise Dimension_Error with "Matrixes must have the same number of rows.";
      end if;
      
      Tmp := new Matrix_Type(1 .. Rows(Left), 1 .. (Cols(Left) + Cols(Right)));
      
      for I in Left'Range(1) loop
	 for J in Left'Range(2) loop
	    Tmp(I, J) := Left(I, J);
	 end loop;
      end loop;
      
      for I in Right'Range(1) loop
	 for J in Right'Range(2) loop
	    Tmp(I, J + Cols(Left)) := Right(I, J);
	 end loop;
      end loop;
      
      Free(Left);
      
      Left := Tmp;
   end;
   
   ------------------ CONVERTERS ------------------
   
   function Copy(Item : in Matrix_Type) return Matrix_Type is
      Result : Matrix_Type(Item'Range(1), Item'Range(2));
   begin
      
      for I in Result'Range(1) loop
	 for J in Result'Range(2) loop
	    Result(I, J) := Item(I, J);
	 end loop;
      end loop;
      
      return Result;
   end Copy;
   
   function Copy(Item : in Matrix) return Matrix is
      Result : Matrix := Copy_Dimension(Item);
   begin
      Result.all := Copy(Item.all);
      return Result;
   end Copy;
   
   function Copy(Item : in Row_Vector) return Row_Vector is
      Result : Row_Vector := Copy_Dimension(Item);
   begin
      Result.all := Copy(Item.all);
      return Result;
   end Copy;
   
   function Copy(Item : in Column_Vector) return Column_Vector is
      Result : Column_Vector := Copy_Dimension(Item);
   begin
      Result.all := Copy(Item.all);
      return Result;
   end Copy;
   
   ------------------------------
   
   function To_Row_Vector(Item : in Matrix) return Row_Vector is
      Result : Row_Vector := Copy_Dimension(Item);
   begin
      Null_Check(Item);
      
      if Rows(Item) /= 1 then
	 raise Dimension_Error with "Unable to convert matrix to Row_Vector";
      end if;
      
      Result.all := Copy(Item.all);
      return Result;
   end To_Row_Vector;
   
   function To_Column_Vector(Item : in Matrix) return Column_Vector is
      Result : Column_Vector := Copy_Dimension(Item);
   begin
      Null_Check(Item);
      
      if Cols(Item) /= 1 then
	 raise Dimension_Error with "Unable to convert matrix to Column_Vector";
      end if;
      
      Result.all := Copy(Item.all);
      return Result;
   end To_Column_Vector;
   
   ------------------------------
   
   function To_Matrix(Item : in Row_Vector) return Matrix is
      Result : Matrix := Copy_Dimension(Item);
   begin
      Result.all := Copy(Item.all);
      return Result;
   end To_Matrix;

   
   function To_Matrix(Item : in Column_Vector) return Matrix is
      Result : Matrix := Copy_Dimension(Item);
   begin
      Result.all := Copy(Item.all);
      return Result;
   end To_Matrix;
   
   ------------------ VECTOR OPERATORS ------------------
   
   function Cross_Product(Left, Right : in Column_Vector) return Column_Vector is
      Result : Column_Vector := new Matrix_Type(1..3, 1..1);
   begin
      Null_Check(Left);
      Null_Check(Right);
      
      if Left'Length(1) /= 3 or Right'Length(1) /= 3 then
	 raise Dimension_Error with "Vector must contain 3 elements to calculate Cross-Product";
      end if;
      
      Result(1, 1) := Left(2, 1) * Right(3, 1) - Left(3, 1) * Right(2, 1);
      Result(2, 1) := Left(3, 1) * Right(1, 1) - Left(1, 1) * Right(3, 1);
      Result(3, 1) := Left(1, 1) * Right(2, 1) - Left(2, 1) * Right(1, 1);
      
      return Result;
   end Cross_Product;
   
   function Dot_Product(Left  : in Column_Vector;
			Right : in Column_Vector) return Float is
      Result : Float := 0.0;
   begin
      Null_Check(Left);
      Null_Check(Right);
      
      if Left'Length(1) /= Right'Length(1) then
	 raise Dimension_Error with "Dot_Product: length mismatch";
      end if;
      
      for I in Left'Range(1) loop
	 Result := Result + Left(I, 1) * Right(I, 1);
      end loop;
      
      return Result;
   end Dot_Product;

   procedure Axpy(Y     : in out Column_Vector;
                  Alpha : in     Float;
                  X     : in     Column_Vector) is
   begin
      Null_Check(Y);
      Null_Check(X);
      if Y'Length(1) /= X'Length(1) then
         raise Dimension_Error with "Axpy: vector length mismatch";
      end if;

      for I in Y'Range(1) loop
         Y(I, 1) := Y(I, 1) + Alpha * X(I, 1);
      end loop;
   end Axpy;

   procedure Map_In_Place(V : in out Column_Vector;
                          F : not null access function(x : Float) return Float) is
   begin
      Null_Check(V);
      for I in V'Range(1) loop
         V(I, 1) := F(V(I, 1));
      end loop;
   end Map_In_Place;

   procedure Softmax_In_Place(V : in out Column_Vector) is
      MaxV : Float;
      SumE : Float := 0.0;
   begin
      Null_Check(V);

      MaxV := V(1, 1);

      -- 1) find max
      for i in V'Range(1) loop
         if V(i, 1) > MaxV then
            MaxV := V(i, 1);
         end if;
      end loop;

      -- 2) subtract max and exp
      for i in V'Range(1) loop
         V(i, 1) := Exp(V(i, 1) - MaxV);
      end loop;

      -- 3) sum
      for i in V'Range(1) loop
         SumE := SumE + V(i, 1);
      end loop;

      -- 4) normalize (guard tiny sums just in case)
      if SumE <= 0.0 then
         -- fallback: uniform distribution
         declare
            n : constant Float := Float(V'Length(1));
         begin
            for i in V'Range(1) loop
               V(i, 1) := 1.0 / n;
            end loop;
         end;
      else
         for i in V'Range(1) loop
            V(i, 1) := V(i, 1) / SumE;
         end loop;
      end if;
   end Softmax_In_Place;

   procedure Hadamard_In_Place (Y : in out Column_Vector;
                                X : in     Column_Vector) is
   begin
      Null_Check(Y);
      Null_Check(X);
      if Y'Length(1) /= X'Length(1) then
         raise Dimension_Error with "Hadamard_In_Place: length mismatch";
      end if;
      for I in Y'Range(1) loop
         Y(I, 1) := Y(I, 1) * X(I, 1);
      end loop;
   end Hadamard_In_Place;

   ------------------ Matrix OPERATORS ------------------

   function L2_Norm (M : in Matrix) return Float is
      Sum : Float := 0.0;
   begin
      for I in M'Range(1) loop
         for J in M'Range(2) loop
            Sum := Sum + M(I,J)**2;
         end loop;
      end loop;
      return Sqrt(Sum);
   end L2_Norm;

   procedure Scale_In_Place (M : in out Matrix;
                             Alpha : in Float) is
   begin
      Null_Check (M);
      for i in M'Range(1) loop
         for j in M'Range(2) loop
            M(i,j) := Alpha * M(i,j);
         end loop;
      end loop;
   end Scale_In_Place;

   -- M: (R×C), B: (R×1)
   procedure Broadcast_Add (M : in out Matrix;
                            B : in     Matrix) is
   begin
      Null_Check (M); Null_Check (B);
      if Rows(M) /= Rows(B) or else Cols(B) /= 1 then
         raise Dimension_Error with "Broadcast_Add: shape mismatch";
      end if;
      for j in 1 .. Cols(M) loop
         for i in 1 .. Rows(M) loop
            M(i, j) := M(i, j) + B(i, 1);
         end loop;
      end loop;
   end Broadcast_Add;

   -- returns 1×C
   function Colwise_Max (M : Matrix) return Matrix is
      R : Matrix := Zeros (1, Cols(M));
   begin
      for j in 1 .. Cols(M) loop
         R(1, j) := M(1, j);
         for i in 2 .. Rows(M) loop
            if M(i, j) > R(1, j) then R(1, j) := M(i, j); end if;
         end loop;
      end loop;
      return R;
   end Colwise_Max;

   function Colwise_Sum (M : Matrix) return Matrix is
      R : Matrix := Zeros (1, Cols(M));
   begin
      for j in 1 .. Cols(M) loop
         declare S : Float := 0.0; begin
            for i in 1 .. Rows(M) loop S := S + M(i, j); end loop;
            R(1, j) := S;
         end;
      end loop;
      return R;
   end Colwise_Sum;

   procedure Softmax_Stable (Z : in out Matrix) is
      use Ada.Numerics.Elementary_Functions;
      MaxRow : Matrix := Colwise_Max (Z);     -- 1×B
   begin
      -- subtract columnwise max
      for j in 1 .. Cols(Z) loop
         for i in 1 .. Rows(Z) loop
            Z(i, j) := Z(i, j) - MaxRow(1, j);
         end loop;
      end loop;

      -- exp
      for j in 1 .. Cols(Z) loop
         for i in 1 .. Rows(Z) loop
            Z(i, j) := Exp (Z(i, j));
         end loop;
      end loop;

      -- sum per column
      declare S : Matrix := Colwise_Sum (Z);  -- 1×B
      begin
         for j in 1 .. Cols(Z) loop
            -- guard tiny sums
            declare denom : constant Float := (if S(1, j) > 0.0 then S(1, j) else 1.0); begin
               for i in 1 .. Rows(Z) loop
                  Z(i, j) := Z(i, j) / denom;
               end loop;
            end;
         end loop;
         Delete (S);
      end;

      Delete (MaxRow);
   end Softmax_Stable;

   function Mean_Columns (M : Matrix) return Matrix is
      R : Matrix := Zeros (Rows(M), 1);
   begin
      for i in 1 .. Rows(M) loop
         declare s : Float := 0.0; begin
            for j in 1 .. Cols(M) loop s := s + M(i, j); end loop;
            R(i,1) := s / Float(Cols(M));
         end;
      end loop;
      return R;
   end Mean_Columns;

   procedure Map_In_Place(M : in out Matrix;
                          F : not null access function (x : Float) return Float) is
   begin
      Null_Check(M);
      for I in M'Range(1) loop
         for II in M'Range(2) loop
            M(I, II) := F(M(I, II));
        end loop;
      end loop;
   end Map_In_Place;

   procedure Hadamard_In_Place(Y : in out Matrix;
                               X : in     Matrix) is
   begin
      Null_Check(Y);
      Null_Check(X);
      if Y'Length(1) /= X'Length(1) or Y'Length(2) /= X'Length(2) then
         raise Dimension_Error with "Hadamard_In_Place: length mismatch";
      end if;
      for I in Y'Range(1) loop
         for II in Y'Range(2) loop
            Y(I, II) := Y(I, II) * X(I, II);
         end loop;
      end loop;
   end Hadamard_In_Place;

   function OneHot_From_Labels(Labels        : in Indices_Array;
                               Num_Classes   : in Positive) return Matrix is
      B : constant Positive := Labels'Length;
      Y : Matrix := Zeros (Num_Classes, B);
   begin
      for j in Labels'Range loop
         declare
            cls : constant Positive := Labels (j);
         begin
            if cls < 1 or else cls > Num_Classes then
               raise Constraint_Error with "OneHot_From_Labels: label out of range";
            end if;
            Y (cls, j) := 1.0;
         end;
      end loop;
      return Y;
   end OneHot_From_Labels;
   
end Gusjo.Math.Linalg;
