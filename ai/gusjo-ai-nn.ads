with Gusjo.Math;  use Gusjo.Math;
with Gusjo.Ai;    use Gusjo.Ai;
with Ada.Text_IO; use Ada.Text_IO;

package Gusjo.Ai.Nn is
   type Dense_Layer is private;
   type Model       is private;

   procedure Create(M      : in out Model;
                    Loss   : in     Loss_Kind := CrossEntropy);

   procedure Add_Dense(M            : in out Model;
                       Inputs       : in     Positive;
                       Outputs      : in     Positive;
                       Act          : in     Activation_Kind := ReLU;
                       Random_Bias  : in     Boolean := False);

   procedure Clear(M : in out Model);

   procedure Set_Loss(M    : in out Model;
                      Loss : in     Loss_Kind);

   procedure Save(M     : in Model;
                  File  : in File_Type);

   procedure Load(M     : in out Model;
                  File  : in     File_Type);

   function Forward(M : in out  Model;
                    X : in      Column_Vector) return Column_Vector;

   procedure Backward(M : in out Model;
                      X : in     Column_Vector;
                      Y : in     Column_Vector);

   procedure Step (M             : in out Model;
                   Learning_Rate : in     Float := 0.01;
                   Clip_Threshold   : in     Float := 0.0);

   procedure Train_Step (M    : in out Model;
                         X, Y : in     Column_Vector;
                         LR   : in     Float := 0.01);

   -- X: (In×B), returns P: (Out×B)
   function Forward_Batch (M : in out Model;
                           X : in     Matrix) return Matrix;

   -- Y: one-hot (Out×B)
   procedure Backward_Batch (M    : in out Model;
                             X, Y : in     Matrix);

   procedure Train_Batch(M: in out Model;
                   X : in     Matrix;
                   Y : in     Matrix;
                   LR : in    Float := 0.01;
                   Epochs : in Integer := 1000);
private

   type Dense_Layer is
      record
         W, B        : Matrix;
         Activation  : Activation_Kind := ReLU;
         Z, A        : Column_Vector;
         dW, dB      : Matrix;
         dA          : Column_Vector;
         A_M, Z_M    : Matrix;
      end record;

   type Layers_Array is 
      array (Positive range <>) of Dense_Layer;

   type Layer_ptr_type
      is access Layers_Array;

   type Model is
      record
         Ls    : Layer_ptr_type := null;
         Loss  : Loss_Kind      := CrossEntropy;
      end record;

end Gusjo.Ai.Nn;