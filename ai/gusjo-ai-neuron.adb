with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Ada.Numerics.Float_Random;
with Gusjo;                             use Gusjo;
with Gusjo.Math;                        use Gusjo.Math;
with Gusjo.Math.Linalg;                 use Gusjo.Math.Linalg;

package body Gusjo.Ai.Neuron is

   procedure Alloc_Weights(Nn : in out Neuron;
                           N  : in     Positive) is
      Tmp : Matrix := Zeros(N, 1);
   begin
      if Nn = null then
         raise Null_Pointer_Exception;
      end if;

      if Nn.W /= null then
         Delete(Nn.W);
      end if;

      Nn.W := To_Column_Vector(Tmp);
      Delete(Tmp);
   end Alloc_Weights;

   procedure Initialize(N        : in out Neuron;
                        Inputs   : in     Positive;
                        Use_Bias : in     Boolean := true) is
   begin
      if N = null then
         Delete(N);
      end if;

      N := New Neuron_Type;
      Alloc_Weights(N, Inputs);
      N.B := 0.0;
      N.Use_Bias := Use_Bias;
   end Initialize;

   procedure Init_Uniform(N      : in out Neuron;
                          Low    : in     Float := -0.5;
                          High   : in     Float := 0.5) is
      Gen : Ada.Numerics.Float_Random.Generator;
      Rng : constant Float := High - Low;
   begin
      Ada.Numerics.Float_Random.Reset(Gen);
      for I in N.W'Range(1) loop
         N.W(I, 1) := Low + Rng * Ada.Numberics.Float_Random.Random(Gen);
      end loop;
      if N.Use_Bias then
         N.B := Low + Rng * Ada.Numberics.Float_Random.Random(Gen);
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
         return 0;
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
      LR       : constant Float := Learning_Rate;
   begin
      for I in N.W'Range(1) loop
         N.W(I, 1) := N.W(I, 1) - LR * Err * X(I, 1);
      end loop;

      if N.Use_Bias then
         N.B := N.B - LR * Err;
      end if;
   end Update;

end Gusjo.Ai.Neuron;
