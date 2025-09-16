with Ada.Unchecked_Deallocation;

with Gusjo.Math;        use Gusjo.Math;
with Gusjo.Math.Linalg; use Gusjo.Math.Linalg;
with Gusjo.Ai;          use Gusjo.Ai;
with Ada.Text_IO;       use Ada.Text_IO;

with Ada.Numerics.Elementary_Functions;   use Ada.Numerics.Elementary_Functions;

package body Gusjo.Ai.Nn is

   -- Deallocator for the layers array pointer
   procedure Free_Layers is new Ada.Unchecked_Deallocation
     (Object => Layers_Array, Name => Layer_ptr_type);

   -- Free matrices/vectors owned by a single layer (not the array itself)
   procedure Free_One_Layer (L : in out Dense_Layer) is
   begin
      Delete(L.W);
      Delete(L.B);
      Delete(L.Z);
      Delete(L.A);
      Delete(L.dW);
      Delete(L.dB);
      Delete(L.dA);
   end Free_One_Layer;

   -- Create an empty model with chosen loss
   procedure Create (M : in out Model; Loss : in Loss_Kind := CrossEntropy) is
   begin
      M.Ls   := null;
      M.Loss := Loss;
   end Create;

   procedure Set_Loss (M : in out Model; Loss : in Loss_Kind) is
   begin
      M.Loss := Loss;
   end Set_Loss;

   -- Append a new dense layer (W: Out×In, B: Out×1)
   procedure Add_Dense(M            : in out Model;
                       Inputs       : in     Positive;
                       Outputs      : in     Positive;
                       Act          : in     Activation_Kind := ReLU;
                       Random_Bias  : in     Boolean := False) is
      Old_Ptr : Layer_ptr_type := M.Ls;
      Old_Len : constant Natural :=
        (if Old_Ptr = null then 0 else Integer (Old_Ptr'Length));
      New_Ptr : Layer_ptr_type := new Layers_Array (1 .. Old_Len + 1);
      Limit : Float;
      F_In  : constant Float := Float (Inputs);
      F_Out : constant Float := Float (Outputs);
   begin
      -- Copy existing layers (shallow copy; matrices remain owned by entries)
      for I in 1 .. Old_Len loop
         New_Ptr (I) := Old_Ptr (I);
      end loop;

      -- Initialize the new last layer
      declare
         L : Dense_Layer renames New_Ptr (Old_Len + 1);
      begin
         L.W          := Zeros(Outputs, Inputs);
         L.B          := Zeros(Outputs, 1);
         L.Activation := Act;

         -- Allocate gradient buffers now (we’ll fill them in Backward later)
         L.dW := Zeros(Outputs, Inputs);
         L.dB := Zeros(Outputs, 1);

         -- Caches (Z, A, dA) remain null until Forward/Backward is implemented

         -- Set random values

         case act is
         when ReLU =>
            Limit := Sqrt(6.0 / F_In);
         when Sigmoid | Softmax=>
            Limit := Sqrt(6.0 / (F_In + F_Out));
         end case;

         Fill_Random_Uniform(L.W, -Limit, Limit);

         if Random_Bias then
            Fill_Random_Uniform(L.B, -Limit, Limit);
         end if;
      end;

      -- Swap in new array; free old array object
      M.Ls := New_Ptr;
      if Old_Ptr /= null then
         Free_Layers(Old_Ptr);
      end if;
   end Add_Dense;

   -- Free all layers (weights, biases, caches, grads) and the array object
   procedure Clear (M : in out Model) is
   begin
      if M.Ls /= null then
         for I in M.Ls'Range loop
            Free_One_Layer (M.Ls (I));
         end loop;
         Free_Layers (M.Ls);
         M.Ls := null;
      end if;
      -- keep M.Loss as-is; or reset if you prefer:
      -- M.Loss := CrossEntropy;
   end Clear;

   -- Stubs for Save/Load (we'll fill these later)
   procedure Save (M    : in Model;
                   File : in File_Type) is
   begin
      -- Plan: write number of layers; per layer write dims, activation,
      -- then all W and B elements in a stable order.
      null;
   end Save;

   procedure Load (M    : in out Model;
                   File : in     File_Type) is
   begin
      -- Plan: read count; resize Ls; allocate W/B and read elements; set activation.
      null;
   end Load;

   function Forward(M : in out  Model;
                    X : in      Column_Vector) return Column_Vector is
      A_prev : Column_Vector := X;

      Zm : Matrix;

      Tmp_L : Dense_Layer;
   begin
      for I in M.Ls'Range loop
         Tmp_L := M.Ls (I);

         -- Z = W * A_prev + B
         Zm := Tmp_L.W * To_Matrix (A_prev);
         Zm := Zm + Tmp_L.B;

         -- cache Z as a fresh column vector
         Delete (Tmp_L.Z);
         Tmp_L.Z := To_Column_Vector (Zm);

         -- apply activation in-place on Z
         case Tmp_L.Activation is
            when Sigmoid =>
               Map_In_Place (Tmp_L.Z, Sigmoid'Access);
            when ReLU =>
               Map_In_Place (Tmp_L.Z, ReLU'Access);
            when Softmax =>
               Softmax_In_Place(Tmp_L.Z);
         end case;

         -- transfer ownership: A takes the buffer, Z is nulled to avoid double free
         Delete (Tmp_L.A);    -- free old A (if any)
         Tmp_L.A := Tmp_L.Z;  -- A now owns the buffer
         Set_To_Null(Tmp_L.Z);     -- *** critical: break the alias ***

         -- next input is this layer's activation (alias, do not delete)
         A_prev := Tmp_L.A;

         Delete (Zm);

         -- write back updated layer
         M.Ls (I) := Tmp_L;
      end loop;

      -- return a fresh copy the caller owns and can Delete safely
      return Copy(A_prev);
   end Forward;

   procedure Backward(M : in out Model;
                      X : in     Column_Vector;
                      Y : in     Column_Vector) is

   begin
      
   end Backward;

   procedure Step (M             : in out Model;
                   Learning_Rate : in     Float := 0.01) is
      L                    : Dense_Layer;
      ScW, ScB, NewW, NewB : Matrix;
   begin
      for I in M.Ls'Range loop
         L := M.Ls(I);
         ScW  := (-Learning_Rate) * L.dW;
         ScB  := (-Learning_Rate) * L.dB;
         NewW := L.w + ScW;
         NewB := L.B + ScB;
         
         Delete(L.W);
         L.W := NewW;
         
         Delete(L.B);
         L.B := NewB;

         Delete(ScW);
         Delete(ScB);
      end loop;
   end Step;
end Gusjo.Ai.Nn;
