with Ada.Text_IO; use Ada.Text_IO;
with Gusjo.Math;  use Gusjo.Math;
With Gusjo;       use Gusjo;

-- N, Range(1) => Rows
-- M, Range(2) => Cols

package Gusjo.Math.Linalg is
   
   ------------------ Get/Put Matrix ------------------
   
   procedure Get(File : in File_Type;
		 Item : in out Matrix;
		 N, M : in Integer);
   
   procedure Get(File : in File_Type;
		 Item : in out Matrix);
   
   procedure Get(Item : in out Matrix;
		 N, M : in Integer);
   
   procedure Get(Item : in out Matrix);
   
   procedure Put(File : in File_Type;
		 Item : in Matrix;
		 Fore : in Integer := 5;
		 Aft  : in Integer := 5;
		 Exp  : in Integer := 0);
   
   procedure Put(Item : in Matrix;
		 Fore : in Integer := 5;
		 Aft  : in Integer := 5;
		 Exp  : in Integer := 0);
   
   ------------------ Get/Put Row_Vector ------------------
   
   procedure Get(File : in File_Type;
		 Item : in out Row_Vector;
		 M    : in Integer);
   
   procedure Get(File : in File_Type;
		 Item : in out Row_Vector);
   
   procedure Get(Item : in out Row_Vector;
		 M    : in Integer);
   
   procedure Get(Item : in out Row_Vector);
   
   procedure Put(File : in File_Type;
		 Item : in Row_Vector;
		 Fore : in Integer := 5;
		 Aft  : in Integer := 5;
		 Exp  : in Integer := 0);
   
   procedure Put(Item : in Row_Vector;
		 Fore : in Integer := 5;
		 Aft  : in Integer := 5;
		 Exp  : in Integer := 0);
   
   ------------------ Get/Put Col_Vector ------------------
   
   procedure Get(File : in File_Type;
		 Item : in out Column_Vector;
		 N    : in Integer);
   
   procedure Get(File : in File_Type;
		 Item : in out Column_Vector);
   
   procedure Get(Item : in out Column_Vector;
		 N    : in Integer);
   
   procedure Get(Item : in out Column_Vector);
   
   procedure Put(File : in File_Type;
		 Item : in Column_Vector;
		 Fore : in Integer := 5;
		 Aft  : in Integer := 5;
		 Exp  : in Integer := 0);
   
   procedure Put(Item : in Column_Vector;
		 Fore : in Integer := 5;
		 Aft  : in Integer := 5;
		 Exp  : in Integer := 0);
   
   ------------------ CREATORS ------------------
   
   function Identity_Matrix(N : in Positive) return Matrix;
   
   function Matrix_With_Num(N, M : in Positive;
			    Value : in Float) return Matrix;
   
   function Matrix_With_Num(N : in Positive;
			    Value : in Float) return Matrix;
   
   function Zeros(N : in Positive) return Matrix;
   
   function Zeros(N, M : in Positive) return Matrix;
   
   function Ones(N : in Positive) return Matrix;
   
   function Ones(N, M : in Positive) return Matrix;

   procedure Fill_Random_Uniform (V : in out Column_Vector;
                                  Low, High : in Float);
   
   function Column2 (X0, X1 : Float) return Column_Vector;
   
   ------------------ GETTERS ------------------
   
   function Rows(Item : in Matrix)        return Positive;
   
   function Cols(Item : in Matrix)        return Positive;

   function Length(V : in Column_Vector) return Positive;
   
   function Length(V : in Row_Vector)    return Positive;
   
   ------------------ OPERATORS ------------------
   
   function "*"(Left, Right : in Matrix)  return Matrix;
   
   function "*"(Left  : in Matrix;
		Right : in Float)                   return Matrix;
   
   function "*"(Left  : in Float;
		Right : in Matrix)                  return Matrix;
   
   function "*"(Left  : in Matrix;
		Right : in Integer)                 return Matrix;
   
   function "*"(Left  : in Integer;
		Right : in Matrix)                  return Matrix;

   function "+"(left, right : in Matrix)  return Matrix;
   
   function Equals(Left, Right : in Matrix) return Boolean;
   
   function Det(Item : in Matrix) return Float;
   
   function Inverse(Item : in Matrix) return Matrix;
   
   function Transpose(Item : in Matrix) return Matrix;
   
   procedure Combine_Vertically(Top    : in out Matrix;
				Bottom : in Matrix);
   
   procedure Combine_Horizontally(Left  : in out Matrix;
				  Right : in Matrix);
   
   ------------------ DELETE ------------------
   
   procedure Delete(Item : in out Matrix);
   
   procedure Delete(Item : in out Row_Vector);
   
   procedure Delete(Item : in out Column_Vector);
   
   ------------------ CONVERTERS ------------------
   
   function Copy(Item : in Matrix) return Matrix;
   
   function Copy(Item : in Row_Vector) return Row_Vector;
   
   function Copy(Item : in Column_Vector) return Column_Vector;
   
   function To_Row_Vector(Item : in Matrix) return Row_Vector;
   
   function To_Column_Vector(Item : in Matrix) return Column_Vector;
   
   function To_Matrix(Item : in Row_Vector) return Matrix;
   
   function To_Matrix(Item : in Column_Vector) return Matrix;
   
   ------------------ VECTOR OPERATORS ------------------
   
   function Cross_Product(Left, Right : in Column_Vector) return Column_Vector;
   
   function Dot_Product(Left  : in Column_Vector;
			Right : in Column_Vector) return Float;

   procedure Axpy (Y : in out Column_Vector;
                   Alpha : in Float;
                   X : in Column_Vector);

   procedure Map_In_Place(V : in out Column_Vector;
                          F : not null access function (x : Float) return Float);
   
   ------------------ EXCEPTIONS ------------------
   
   Dimension_Error        : exception;
   Invertion_Error        : exception;
   
private
end Gusjo.Math.Linalg;
