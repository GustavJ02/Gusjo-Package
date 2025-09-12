with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Ada.Numerics.Float_Random;
with Gusjo;                             use Gusjo;
with Gusjo.Math;                        use Gusjo.Math;
with Gusjo.Math.Linalg;                 use Gusjo.Math.Linalg;

with Ada.Unchecked_Deallocation;

package body Gusjo.Ai.Neuron is

   procedure Free is new Ada.Unchecked_Deallocation(Neuron_Type, Neuron);

   procedure Initialize(N        : in out Neuron;
                        Inputs   : in     Positive;
                        Use_Bias : in     Boolean := true) is
      Tmp : Matrix := Zeros(N => N, M => 1);
   begin
      if N /= null then
         Free(N);
      end if;

      N := New Neuron_Type;
      N.W := To_Column_Vector(Tmp);
      Delete(Tmp);
      N.B := 0.0;
      N.Use_Bias := Use_Bias;
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

   function Sigmoid(Z : in Float) return Float is
   begin
      return 1.0 / (1.0 + Exp(-Z));
   end Sigmoid;

   function RelU(Z : in Float) return Float is
   begin
      if Z <= 0 then
         return 0.0;
      else
         return Z;
      end if;
   end RelU;

   function Forward(N : in Neuron;
                    X : in Column_Vector) return Float is
      Z : Float;
   begin
      Z := Dot_Product(N.W, X);
      if N.Use_Bias then
         Z := Z + N.B;
      end if;
      return Sigmoid (Z);
   end Forward;

   procedure Update(N               : in out Neuron;
                    X               : in     Column_Vector;
                    Y_True          : in     Float;
                    Learning_Rate   : in     Float := 0.01) is
      Y_Pred   : constant Float := Forward(N, X);
      Err      : constant Float := Y_Pred - Y_True;
   begin
      Axpy(Y => N.W, Alpha => -Learning_Rate * Err, X => X);

      if N.Use_Bias then
         N.B := N.B - Learning_Rate * Err;
      end if;
   end Update;

end Gusjo.Ai.Neuron;
