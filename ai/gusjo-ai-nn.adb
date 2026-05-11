with Ada.Unchecked_Deallocation;

with Gusjo.Math;        use Gusjo.Math;
with Gusjo.Math.Linalg; use Gusjo.Math.Linalg;
with Gusjo.Ai;          use Gusjo.Ai;

with Ada.Text_IO;          use Ada.Text_IO;
with Ada.Integer_Text_IO;  use Ada.Integer_Text_IO;

with Ada.Numerics.Elementary_Functions;   use Ada.Numerics.Elementary_Functions;

package body Gusjo.Ai.Nn is

   -- Deallocator for the layers array pointer
   procedure Free_Layers is new Ada.Unchecked_Deallocation
    (Object => Layers_Array, Name => Layer_ptr_type);

   -- Free matrices/vectors owned by a single layer(not the array itself)
   procedure Free_One_Layer(L : in out Dense_Layer) is
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
   procedure Create(M : in out Model; Loss : in Loss_Kind := CrossEntropy) is
   begin
      M.Ls   := null;
      M.Loss := Loss;
   end Create;

   procedure Set_Loss(M : in out Model; Loss : in Loss_Kind) is
   begin
      M.Loss := Loss;
   end Set_Loss;

   -- Append a new dense layer(W: Out×In, B: Out×1)
   procedure Add_Dense(M            : in out Model;
                       Inputs       : in     Positive;
                       Outputs      : in     Positive;
                       Act          : in     Activation_Kind := ReLU;
                       Random_Bias  : in     Boolean := False) is
      Old_Ptr : Layer_ptr_type := M.Ls;
      Old_Len : constant Natural :=
       (if Old_Ptr = null then 0 else Integer(Old_Ptr'Length));
      New_Ptr : Layer_ptr_type := new Layers_Array(1 .. Old_Len + 1);
      Limit : Float;
      F_In  : constant Float := Float(Inputs);
      F_Out : constant Float := Float(Outputs);
   begin
      -- Copy existing layers(shallow copy; matrices remain owned by entries)
      for I in 1 .. Old_Len loop
         New_Ptr(I) := Old_Ptr(I);
      end loop;

      -- Initialize the new last layer
      declare
         L : Dense_Layer renames New_Ptr(Old_Len + 1);
      begin
         L.W          := Zeros(Outputs, Inputs);
         L.B          := Zeros(Outputs, 1);
         L.Activation := Act;

         -- Allocate gradient buffers now(we’ll fill them in Backward later)
         L.dW := Zeros(Outputs, Inputs);
         L.dB := Zeros(Outputs, 1);

         -- Caches(Z, A, dA) remain null until Forward/Backward is implemented

         -- Set random values

         case act is
         when ReLU =>
            Limit := Sqrt(6.0 / F_In);
         when Sigmoid | Softmax=>
            Limit := Sqrt(6.0 /(F_In + F_Out));
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
   procedure Clear(M : in out Model) is
   begin
      if M.Ls /= null then
         for I in M.Ls'Range loop
            Free_One_Layer(M.Ls(I));
         end loop;
         Free_Layers(M.Ls);
         M.Ls := null;
      end if;
      -- keep M.Loss as-is; or reset if you prefer:
      -- M.Loss := CrossEntropy;
   end Clear;

   -- Stubs for Save/Load (we'll fill these later)
   procedure Save(M    : in Model;
                   File : in File_Type) is
      L : Dense_Layer;
   begin
      Put_Line(File, "GUSJO_NN v1");
      Put_Line(File, To_String(M.Loss));
      if M.Ls = null then
         Put_Line(File, "0");
         return;
      end if;

      Put(File, Integer(M.Ls'Length), Width => 0);
      New_Line(File);

      for I in M.Ls'Range loop
         L := M.Ls(I);
         Put_Line(File, To_String(L.Activation));

         Put_Line(File, "W");
         Put(File, L.W);  -- <-- your Put

         Put_Line(File, "B");
         Put(File, L.B);  -- <-- your Put
      end loop;
   end Save;

   function Read_Line(File : in File_Type) return String is
      S : constant String := Get_Line(File);
   begin
      return S;
   end Read_Line;

   procedure Load(M    : in out Model;
                   File : in     File_Type) is

      Header : constant String := Read_Line(File);
      Maybe_Loss_Line : String := "";
      Layer_Count     : Integer;
      Loss_Read       : Boolean := False;
   begin
      if Header /= "GUSJO_NN v1" then
         raise Constraint_Error with "Load: bad header '" & Header & "'";
      end if;

      -- Try to read a loss line; if it parses, use it; otherwise treat it as the count
      declare
         Line2 : constant String := Read_Line(File);
      begin
         begin
            -- attempt parse as loss; if it fails, we'll treat Line2 as count
            M.Loss := To_Loss_Kind (Line2);
            Loss_Read := True;
         exception
            when others =>
               -- Not a loss string; interpret as count
               declare
                  C : Integer := Integer'Value (Line2);
               begin
                  Layer_Count := C;
               exception
                  when others =>
                     raise Constraint_Error with "Load: expected loss or layer count after header";
               end;
         end;
         if Loss_Read then
            -- next line must be layer count
            Get (File, Layer_Count);
            Skip_Line (File);
         end if;
      end;

      -- Reset current model
      Clear (M);

      if Layer_Count <= 0 then
         return;
      end if;

      -- Rebuild layers
      for Lidx in 1 .. Layer_Count loop
         declare
            Act_Str : constant String := Read_Line(File);
            Act     : Activation_Kind := To_Activation_Kind (Act_Str);

            TagW    : constant String := Read_Line(File);
         begin
            if TagW /= "W" then
               raise Constraint_Error with "Load: expected 'W', got '" & TagW & "'";
            end if;

            -- Read W to get sizes, then add the layer and overwrite its W/B
            declare
               Wtmp   : Matrix;
            begin
               Get(File, Wtmp);  -- reads dims + values (your Get)
               Skip_Line(File);
               declare
                  Inputs  : Positive := Positive (Cols (Wtmp));
                  Outputs : Positive := Positive (Rows (Wtmp));
               begin
                  Add_Dense (M, Inputs => Inputs, Outputs => Outputs, Act => Act);

                  declare
                     L : Dense_Layer renames M.Ls (M.Ls'Last);
                  begin
                     Delete(L.W);
                     L.W := Wtmp;
                  end;
               end;

               -- Read B
               declare
                  TagB : constant String := Read_Line(File);
               begin
                  if TagB /= "B" then
                     raise Constraint_Error with "Load: expected 'B', got '" & TagB & "'";
                  end if;
               end;
               declare
                  Btmp : Matrix;
                  L    : Dense_Layer renames M.Ls (M.Ls'Last);
               begin
                  Get(File, Btmp);  -- reads dims + values
                  Skip_Line(File);
                  Delete(L.B);
                  L.B := Btmp;
               end;
            end;
         end;
      end loop;
   end Load;

   function Forward(M : in out  Model;
                    X : in      Column_Vector) return Column_Vector is
      A_prev : Column_Vector := X;

      Zm : Matrix;

      Tmp_L : Dense_Layer;
   begin
      for I in M.Ls'Range loop
         Tmp_L := M.Ls(I);

         -- Z = W * A_prev + B
         Zm := Tmp_L.W * To_Matrix(A_prev);
         Zm := Zm + Tmp_L.B;

         -- cache Z as a fresh column vector
         Delete(Tmp_L.Z);
         Tmp_L.Z := To_Column_Vector(Zm);

         -- apply activation in-place on Z
         case Tmp_L.Activation is
            when Sigmoid =>
               Map_In_Place(Tmp_L.Z, Sigmoid'Access);
            when ReLU =>
               Map_In_Place(Tmp_L.Z, ReLU'Access);
            when Softmax =>
               Softmax_In_Place(Tmp_L.Z);
         end case;

         -- transfer ownership: A takes the buffer, Z is nulled to avoid double free
         Delete(Tmp_L.A);    -- free old A (if any)
         Tmp_L.A := Tmp_L.Z;  -- A now owns the buffer
         Set_To_Null(Tmp_L.Z);     -- *** critical: break the alias ***

         -- next input is this layer's activation (alias, do not delete)
         A_prev := Tmp_L.A;

         Delete(Zm);

         -- write back updated layer
         M.Ls(I) := Tmp_L;
      end loop;

      -- return a fresh copy the caller owns and can Delete safely
      return Copy(A_prev);
   end Forward;

   -- Elementwise derivative from activation **using A only** (no need for Z)
   function Derivative_From_A(Act : Activation_Kind;
                              A : Column_Vector) return Column_Vector is
      D : Column_Vector := Copy(A);  -- start from A
      -- local elementwise maps
   begin
      case Act is
         when Sigmoid =>
            Map_In_Place(D, Sigmoid_Derivative'Access);
         when ReLU =>
            Map_In_Place(D, Relu_Derivative'Access);
         when Softmax =>
            -- We avoid the full Jacobian; handle Softmax only paired with CE elsewhere.
            raise Constraint_Error with "Derivative_From_A: Softmax derivative not supported here";
      end case;
      return D;
   end Derivative_From_A;

   -- Compute dZ for last layer under the chosen loss
   --  * CrossEntropy + (Softmax or Sigmoid): dZ = A - Y
   --  * Otherwise (e.g., MSE): dZ = (A - Y) ⊙ g'(A)
   function Compute_dZ_Last(Loss : Loss_Kind;
                            Act : Activation_Kind;
                            A_Last, Y : Column_Vector) return Column_Vector is

      Diff : Matrix := To_Matrix(A_Last) - To_Matrix(Y);
      dZ   : Column_Vector := To_Column_Vector(Diff);
   begin
      Delete(Diff);

      if Loss = CrossEntropy and then (Act = Softmax or else Act = Sigmoid) then
         -- fast path: dZ = A - Y
         return dZ;
      end if;

      -- General case (e.g., MSE): multiply by activation derivative
      declare
         Der : Column_Vector := Derivative_From_A(Act, A_Last);
      begin
         Hadamard_In_Place(dZ, Der);
         Delete(Der);
         return dZ;
      end;
   end Compute_dZ_Last;

   -- Set gradients for a layer:
   --    dW := dZ * A_prev^T   (Out×1 * 1×In = Out×In)
   --    dB := dZ              (Out×1)
   procedure Set_Grads(L : in out Dense_Layer;
                       dZ, A_Prev : Column_Vector) is

      A_T  : Matrix := Transpose(To_Matrix(A_Prev));
      dZ_M : Matrix := To_Matrix(dZ);
      dW   : Matrix := dZ_M * A_T;
      dB   : Matrix := To_Matrix(dZ);
   begin
      Delete(L.dW);
      L.dW := dW;
      
      Delete(L.dB);
      L.dB := dB;

      Delete(A_T);
      Delete(dZ_M);
   end Set_Grads;

   -- Propagate gradient to previous activation:
   --    dA_prev := W^T * dZ
   function Propagate_dA_Prev(W  : in Matrix;
                              dZ : in Column_Vector) return Column_Vector is

      WT   : Matrix := Transpose(W);
      dZ_M : Matrix := To_Matrix(dZ);
      Prod : Matrix := WT * dZ_M;
      Res  : Column_Vector := To_Column_Vector(Prod);
   begin
      Delete(WT);
      Delete(dZ_M);
      Delete(Prod);
      return Res;
   end Propagate_dA_Prev;

   procedure Backward(M : in out Model;
                      X : in     Column_Vector;
                      Y : in     Column_Vector) is
      -- gradient wrt activation of the previous layer (flows backward)
      dA_prev : Column_Vector;

      -- last layer references
      L_last  : Dense_Layer renames M.Ls(M.Ls'Last);
      A_prev  : Column_Vector := (if M.Ls'Length = 1 then X else M.Ls(M.Ls'Last - 1).A);

      -- last layer gradient wrt logits
      dZ_last : Column_Vector;
   begin
      -- 1) Last layer: compute dZ
      dZ_last := Compute_dZ_Last(M.Loss, L_last.Activation, L_last.A, Y);

      -- 2) Last layer: dW/dB and dA_prev
      Set_Grads(L_last, dZ_last, A_prev);
      dA_prev := Propagate_dA_Prev(L_last.W, dZ_last);

      Delete(dZ_last);

      -- 3) Hidden layers(reverse order)
      for idx in reverse M.Ls'First .. M.Ls'Last - 1 loop
         declare
            L      : Dense_Layer renames M.Ls(idx);
            A_prevL: Column_Vector :=(if idx = M.Ls'First then X else M.Ls(idx - 1).A);
            -- dZ = dA_prev ⊙ g'(A)
            dZ     : Column_Vector := Copy(dA_prev);
            Der    : Column_Vector := Derivative_From_A(L.Activation, L.A);
         begin
            Hadamard_In_Place(dZ, Der);
            Delete(Der);

            Set_Grads(L, dZ, A_prevL);

            -- next dA_prev = W^T * dZ
            declare
               Next : Column_Vector := Propagate_dA_Prev(L.W, dZ);
            begin
               Delete(dA_prev);
               dA_prev := Next;
            end;

            Delete(dZ);
         end;
      end loop;

      Delete(dA_prev);
   end Backward;

   procedure Step(M                 : in out Model;
                   Learning_Rate    : in     Float := 0.01;
                   Clip_Threshold   : in     Float := 0.0) is

      L                    : Dense_Layer;
      ScW, ScB, NewW, NewB : Matrix;
      Norm, NormW, NormB, Scale : Float;
   begin
      for I in M.Ls'Range loop
         L := M.Ls(I);

         NormW := L2_Norm(L.dW);
         NormB := L2_Norm(L.dB);
         Norm  := Sqrt(NormW ** 2 + NormB ** 2);
         Scale := Clip_Threshold / Norm;

         if (Clip_Threshold > 0.0) and then Norm > Clip_Threshold then
            Scale_In_Place(L.dW, Scale);
            Scale_In_Place(L.dB, Scale);
         end if;

         ScW  :=(-Learning_Rate) * L.dW;
         ScB  :=(-Learning_Rate) * L.dB;
         NewW := L.w + ScW;
         NewB := L.B + ScB;
         
         Delete(L.W);
         L.W := NewW;
         
         Delete(L.B);
         L.B := NewB;

         Delete(ScW);
         Delete(ScB);

         M.Ls(I) := L;
      end loop;
   end Step;

   procedure Train_Step(M : in out Model; X, Y : Column_Vector; LR : Float := 0.01) is
      P : Column_Vector := Forward(M, X);
   begin
      Delete(P);               -- caches already stored in model
      Backward(M, X, Y);
      Step(M, Learning_Rate => LR);
   end Train_Step;

   function Forward_Batch(M : in out Model;
                           X : in     Matrix) return Matrix is
      A_prev : Matrix := X;  -- alias; do not Delete(X)
   begin
      if M.Ls = null or else M.Ls'Length = 0 then
         raise Constraint_Error with "Forward_Batch: model has no layers";
      end if;

      for I in M.Ls'Range loop
         declare
            L : Dense_Layer renames M.Ls (I);
            Z : Matrix := L.W * A_prev;                 -- (Out×In)*(In×B) = (Out×B)
         begin
            Broadcast_Add (Z, L.B);                     -- + bias columnwise

            case L.Activation is
               when ReLU    => Map_In_Place (Z, ReLU'Access);
               when Sigmoid => Map_In_Place (Z, Sigmoid'Access);
               when Softmax => Softmax_Stable (Z);      -- column-wise
            end case;

            -- cache activations for this layer
            Delete(L.A_M);
            L.A_M := Z;                                 -- model owns Z

            if I = M.Ls'Last then
               return Copy (Z);                         -- caller owns the copy
            else
               A_prev := L.A_M;                         -- next layer input
            end if;
         end;
      end loop;

      raise Program_Error with "Forward_Batch: unexpected fallthrough";
   end Forward_Batch;

   procedure Backward_Batch (M    : in out Model;
                          X, Y : in     Matrix) is
      -- ensure caches are current
      P_Tmp : Matrix := Forward_Batch (M, X);  -- Out×B
      B  : constant Float := Float (Cols (X));  -- batch size

      -- last layer shorthand
      L_last : Dense_Layer renames M.Ls (M.Ls'Last);

      -- gradient wrt logits/activations for current layer (matrix)
      dZ : Matrix;
   begin
      Delete(P_Tmp);  -- we only needed caches in the model

      -- --- Last layer ---
      -- CE + Softmax/Sigmoid ⇒ dZ = A_L - Y
      dZ := L_last.A_M - Y;

      declare
         A_prev : Matrix := (if M.Ls'Length = 1 then X else M.Ls(M.Ls'Last - 1).A_M);
         dW     : Matrix := (dZ * Transpose(A_prev)) * (1.0 / B);  -- Out×In
         dB     : Matrix := Mean_Columns(dZ);                       -- Out×1
         dA_prev: Matrix := Transpose(L_last.W) * dZ;               -- In×B
      begin
         Delete(L_last.dW);
         L_last.dW := dW;
         
         Delete(L_last.dB);
         L_last.dB := dB;

         -- --- Hidden layers (reverse) ---
         for idx in reverse M.Ls'First .. M.Ls'Last - 1 loop
            declare
               L      : Dense_Layer renames M.Ls(idx);
               A_prevL: Matrix := (if idx = M.Ls'First then X else M.Ls(idx - 1).A_M);

               -- dZ = dA_prev ⊙ g'(A_l)
               dZ_H : Matrix := Copy(dA_prev);   -- start from dA_prev
               Der  : Matrix := Copy(L.A_M);     -- copy of A_l to turn into derivative
            begin
               case L.Activation is
                  when Sigmoid => Map_In_Place(Der, Sigmoid_Derivative'Access);
                  when ReLU    => Map_In_Place(Der, Relu_Derivative'Access);
                  when Softmax =>
                     raise Constraint_Error with "Softmax should only be the final layer";
               end case;

               Hadamard_In_Place(dZ_H, Der);     -- dZ_H *= Der
               Delete(Der);

               -- grads for this layer
               declare
                  dW_L : Matrix := (dZ_H * Transpose(A_prevL)) * (1.0 / B);
                  dB_L : Matrix := Mean_Columns(dZ_H);
               begin
                  Delete(L.dW);
                  L.dW := dW_L;
                  
                  Delete(L.dB);
                  L.dB := dB_L;
               end;

               -- propagate to next (earlier) layer
               declare
                  Next_dA : Matrix := Transpose(L.W) * dZ_H;
               begin
                  Delete(dA_prev);
                  dA_prev := Next_dA;
               end;

               Delete(dZ_H);
            end;
         end loop;

         Delete(dA_prev);
      end;

      Delete(dZ);
   end Backward_Batch;

end Gusjo.Ai.Nn;
