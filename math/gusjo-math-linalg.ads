with Ada.Text_IO; use Ada.Text_IO;
with Gusjo.Math;  use Gusjo.Math;
With Gusjo;       use Gusjo;

-- N, Range(1) => Rows
-- M, Range(2) => Cols

package Gusjo.Math.Linalg is

   ------------------ Types ------------------

   type Indices_Array is array (Positive range <>) of Positive;

   type Column_Vector_Array is array (Positive range <>) of Column_Vector;

   type Row_Vector_Array is array (Positive range <>) of Row_Vector;
   
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

   procedure Fill_Random_Uniform(V           : in out Column_Vector;
                                 Low, High   : in     Float);

   procedure Fill_Random_Uniform(M           : in out Matrix;
                                 Low, High   : in     Float);
   
   function Column1(X0 : Float) return Column_Vector;

   function Column2(X0, X1 : Float) return Column_Vector;

   function Column3(X0, X1, X2 : Float) return Column_Vector;

   function Row1(X0 : Float) return Row_Vector;

   function Row2(X0, X1 : Float) return Row_Vector;

   function Row3(X0, X1, X2 : Float) return Row_Vector;

   function HStack_Columns(Vs : in Column_Vector_Array) return Matrix;

   function VStack_Rows(Rs : in Row_Vector_Array) return Matrix;
   
   ------------------ GETTERS ------------------
   
   function Rows(Item : in Matrix)        return Positive;
   
   function Cols(Item : in Matrix)        return Positive;

   function Length(V : in Column_Vector) return Positive;
   
   function Length(V : in Row_Vector)    return Positive;

   function Argmax(V : in Column_Vector) return Positive;

   function Argmax_Columns(P : in Matrix) return Indices_Array;

   function CrossEntropy_OneHot(P, Y : in Column_Vector) return Float;

   function CrossEntropy_OneHot(P, Y : in Matrix) return Float;
   
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

   function "-"(Left, Right : in Matrix)  return Matrix;
   
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

   procedure Set_To_Null(Item : in out Matrix);
   
   procedure Set_To_Null(Item : in out Row_Vector);
   
   procedure Set_To_Null(Item : in out Column_Vector);
   
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

   procedure Softmax_In_Place(V : in out Column_Vector);

   procedure Hadamard_In_Place(Y : in out Column_Vector;
                               X : in     Column_Vector);

   ------------------ Matrix OPERATORS ------------------

   function L2_Norm(M : in Matrix) return Float;

   procedure Scale_In_Place (M     : in out Matrix;
                             Alpha : in     Float);

   procedure Broadcast_Add (M : in out Matrix;
                            B : in     Matrix);

   function Colwise_Max (M : Matrix) return Matrix;

   function Colwise_Sum (M : Matrix) return Matrix;

   procedure Softmax_Stable (Z : in out Matrix);

   function Mean_Columns (M : Matrix) return Matrix;

   procedure Map_In_Place(M : in out Matrix;
                          F : not null access function (x : Float) return Float);

   procedure Hadamard_In_Place(Y : in out Matrix;
                               X : in     Matrix);

   function OneHot_From_Labels(Labels        : in Indices_Array;
                               Num_Classes   : in Positive) return Matrix;
   
   ------------------ EXCEPTIONS ------------------
   
   Dimension_Error        : exception;
   Invertion_Error        : exception;
   
private
end Gusjo.Math.Linalg;
