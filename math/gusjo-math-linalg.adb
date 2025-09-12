with Ada.Integer_Text_IO;        use Ada.Integer_Text_IO;
with Ada.Float_Text_IO;          use Ada.Float_Text_IO;
with Ada.Unchecked_Deallocation;
with Ada.Numerics.Float_Random;

package body Gusjo.Math.Linalg is
   
   procedure Free is new Ada.Unchecked_Deallocation(Matrix_Type, Matrix);
   
   procedure Free is new Ada.Unchecked_Deallocation(Matrix_Type, Row_Vector);
   
   procedure Free is new Ada.Unchecked_Deallocation(Matrix_Type, Column_Vector);
   
   procedure Delete(Item : in out Matrix) is
   begin
      Free(Item);
   end Delete;
   
   procedure Delete(Item : in out Row_Vector) is
   begin
      Free(Item);
   end Delete;
   
   procedure Delete(Item : in out Column_Vector) is
   begin
      Free(Item);
   end Delete;
   
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
      
      Put_Line("N:" & N'Image);
      Put_Line("M:" & M'Image);
      
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
      for I in Item'Range(1) loop
	 for J in Item'Range(2) loop
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
      Square_Check(Item);
      
      Result := new Matrix_Type(Item'Range(1), Item'Range(2));
      
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

   procedure Fill_Random_Uniform (V : in out Column_Vector; Low, High : in Float) is
      Gen : Ada.Numerics.Float_Random.Generator;
      Rng : constant Float := High - Low;
   begin
      Null_Check (V);
      Ada.Numerics.Float_Random.Reset(Gen);
      for I in V'Range(1) loop
         V(I, 1) := Low + Rng * Ada.Numerics.Float_Random.Random(Gen);
      end loop;
   end Fill_Random_Uniform;

   function Column2 (X0, X1 : Float) return Column_Vector is
      M : Matrix := Zeros (2, 1);
      R : Column_Vector;
   begin
      M (1, 1) := X0;
      M (2, 1) := X1;
      R := To_Column_Vector (M);
      Delete (M);
      return R;
   end Column2;

   
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

   function Length (V : in Column_Vector) return Positive is
   begin
      Null_Check (V);
      return Positive (V'Length (1));
   end Length;

   function Length (V : in Row_Vector) return Positive is
   begin
      Null_Check (V);
      return Positive (V'Length (2));
   end Length;
   
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
      Sum    : Float;
   begin
      Null_Check(Left);
      Null_Check(Right);
      
      if Cols(Left) /= Rows(Right) then
	 raise Dimension_Error with "Number of collumns in left matrix must equal number of rows in right matrix";
      end if;
      
      Result := new Matrix_Type(1..Rows(Left), 1..Cols(Right));
      
      for I in Left'Range(1) loop
	 for K in Right'range(2) loop
	    Sum := 0.0;
	    
	    for J in Left'Range(2) loop
	       Sum := Sum + Left(I, J) * Right(J, K);
	    end loop;
	    
	    Result(I, K) := Sum;
	 end loop;
      end loop;
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
   	 if (I + J) mod 2 = 0 then
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

   procedure Axpy (Y     : in out Column_Vector;
                   Alpha : in     Float;
                   X     : in     Column_Vector) is
   begin
      Null_Check (Y);
      Null_Check (X);
      if Y'Length (1) /= X'Length (1) then
         raise Dimension_Error with "Axpy: vector length mismatch";
      end if;

      for I in Y'Range (1) loop
         Y (I, 1) := Y (I, 1) + Alpha * X (I, 1);
      end loop;
   end Axpy;
   
end Gusjo.Math.Linalg;
