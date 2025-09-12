with Gusjo.Math;        use Gusjo.Math;

package Gusjo.Ai.Neuron is

   type Neuron is private;

   procedure Initialize(N        : in out Neuron;
                        Inputs   : in     Positive;
                        Use_Bias : in     Boolean := true);

   procedure Init_Uniform(N      : in out Neuron;
                          Low    : in     Float := -0.5;
                          High   : in     Float := 0.5);

   function Forward(N : in Neuron;
                    X : in Column_Vector) return Float;

   procedure Update(N               : in out Neuron;
                    X               : in     Column_Vector;
                    Y_True          : in     Float;
                    Learning_Rate   : in     Float := 0.01);

private

   type Neuron_Type is record
      W        : Column_Vector;
      B        : Float;
      Use_Bias : Boolean := true;
   end record;

   type Neuron is
      access Neuron_Type;

end Gusjo.Ai.Neuron;
