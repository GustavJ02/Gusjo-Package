with Ada.Numerics.Float_Random;
with Gusjo;                             use Gusjo;
with Gusjo.Math;                        use Gusjo.Math;
with Gusjo.Math.Linalg;                 use Gusjo.Math.Linalg;

with Ada.Unchecked_Deallocation;

package body Gusjo.Ai.Neuron is

   procedure Free is new Ada.Unchecked_Deallocation(Neuron_Type, Neuron);

   procedure Initialize(N           : in out Neuron;
                        Inputs      : in     Positive;
                        Use_Bias    : in     Boolean           := true;
                        Activation  : in     Activation_Kind   := Sigmoid;
                        Loss        : in     Loss_Kind         := MSE) is
      Tmp : Matrix := Zeros(Inputs, 1);
   begin
      if N /= null then
         Free(N);
      end if;

      N := New Neuron_Type;
      N.W := To_Column_Vector(Tmp);
      Delete(Tmp);
      N.B := 0.0;
      N.Use_Bias := Use_Bias;
      N.Activation := Activation;
      N.Loss := Loss;
   end Initialize;

   procedure Init_Uniform(N      : in out Neuron;
                          Low    : in     Float := -0.5;
                          High   : in     Float := 0.5) is
      Gen : Ada.Numerics.Float_Random.Generator;
      Rng : constant Float := High - Low;
   begin
      Fill_Random_Uniform (N.W, Low, High);
      if N.Use_Bias then
         N.B := Low + (Rng * Ada.Numerics.Float_Random.Random(Gen));
      else
         N.B := 0.0;
      end if;
   end Init_Uniform;

   function Activate(A : Activation_Kind; Z : Float) return Float is
   begin
      case A is
         when Sigmoid => return Sigmoid(Z);
         when ReLU    => return ReLU(Z);
         when Softmax => raise Constraint_Error with "Unable to use Softmax for single neuron.";
      end case;
   end;

   function DActivate(A : Activation_Kind; Z, Y : Float) return Float is
   begin
      case A is
         when Sigmoid => return Y * (1.0 - Y);
         when ReLU    =>
            if Z > 0.0 then 
               return 1.0;
            else 
               return 0.0;
            end if;
         when Softmax => raise Constraint_Error with "Unable to use Softmax for single neuron.";
      end case;
   end;

   function Forward(N : in Neuron;
                    X : in Column_Vector) return Float is
      Z : Float;
   begin
      Z := Dot_Product(N.W, X);
      if N.Use_Bias then
         Z := Z + N.B;
      end if;
      return Activate(N.Activation, Z);
   end Forward;

   procedure Update(N               : in out Neuron;
                    X               : in     Column_Vector;
                    Y_True          : in     Float;
                    Learning_Rate   : in     Float := 0.01) is
      Z, Y_Pred, dA, dZ : Float;
   begin
      Z := Dot_Product(N.W, X);
      if N.Use_Bias then
         Z := Z + N.B;
      end if; 

      Y_Pred := Activate(N.Activation, Z);

      -- Choose dA by loss
      case N.Loss is
         when MSE =>
            dA := Y_Pred - Y_True;
            dZ := dA * DActivate(N.Activation, Z, Y_Pred);

         when CrossEntropy =>
            -- Valid only with Sigmoid output
            if N.Activation = Sigmoid then
               -- BCE + Sigmoid: dL/dz = ŷ - y (fast path)
               dZ := Y_Pred - Y_True;
            else
               raise Constraint_Error with "CrossEntropy requires Sigmoid activation";
            end if;
      end case;

      -- gradient step
      Axpy(Y => N.W, Alpha => -Learning_Rate * dZ, X => X);
      if N.Use_Bias then
         N.B := N.B - Learning_Rate * dZ;
      end if;
   end Update;

end Gusjo.Ai.Neuron;
