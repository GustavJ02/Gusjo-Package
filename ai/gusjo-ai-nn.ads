with Gusjo.Math;  use Gusjo.Math;
with Gusjo.Ai;    use Gusjo.Ai;
with Ada.Text_IO; use Ada.Text_IO;

package Gusjo.Ai.Nn is
   type Dense_Layer is private;
   type Model       is private;

   procedure Create(M      : in out Model;
                    Loss   : in     Loss_Kind := CrossEntropy);

   procedure Add_Dense(M         : in out Model;
                       Inputs    : in     Positive;
                       Outputs   : in     Positive;
                       Act       : in     Activation_Kind := ReLU);

   procedure Clear(M : in out Model);

   procedure Set_Loss(M    : in out Model;
                      Loss : in     Loss_Kind);

   procedure Save(M     : in Model;
                  File  : in File_Type);

   procedure Load(M     : in out Model;
                  File  : in     File_Type);

   function Forward(M : in out  Model;
                    X : in      Column_Vector) return Column_Vector;

private

   type Dense_Layer is
      record
         W, B        : Matrix;
         Activation  : Activation_Kind := ReLU;
         Z, A        : Column_Vector;
         dW, dB      : Matrix;
         dA          : Column_Vector;
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