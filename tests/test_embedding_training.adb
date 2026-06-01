with Ada.Text_IO;              use Ada.Text_IO;
with Gusjo.GPT.Tokenizer;      use Gusjo.GPT.Tokenizer;
with Gusjo.GPT.Embedding;      use Gusjo.GPT.Embedding;
with Gusjo.Math;               use Gusjo.Math;
with Gusjo.Math.Linalg;        use Gusjo.Math.Linalg;
with Gusjo.Math.Optimization;  use Gusjo.Math.Optimization;

procedure Test_Embedding_Training is
   T            : BPE_Tokenizer;
   E, E2        : Embedding_Layer;
   Grad_Weights : Matrix;
   Config       : Optimizer_Config := (Method => AdamW, others => <>);
   State        : Optimizer_State (Kind => AdamW);
   IDs1         : ID_Vec.Vector;
   D_Output     : Matrix;
   Output1, Output2, Output3 : Matrix;
   Seq_Len      : Positive;
   First_Token  : Positive;
begin
   T    := Load ("wiki_tokenizer.dat");
   E    := Create (8000, 64);
   Initialize (E);
   Grad_Weights := Zeros (8000, 64);

   IDs1    := Encode (T, "hello world");
   Seq_Len := Positive (Natural (IDs1.Length));
   Output1 := Forward (E, IDs1);

   D_Output := Zeros (Seq_Len, 64);
   for R in 1 .. Seq_Len loop
      for C in 1 .. 64 loop
         Element_at (D_Output, R, C, 0.1);
      end loop;
   end loop;

   Backward (E, IDs1, D_Output, Grad_Weights);

   -- Check 1: Backward accumulates gradients
   First_Token := Positive (Natural (ID_Vec.Element (IDs1, IDs1.First_Index))) + 1;
   if Element_at (Grad_Weights, First_Token, 1) /= 0.0 then
      Put_Line ("PASS: Backward accumulates gradients");
   else
      Put_Line ("FAIL: Backward did not accumulate gradients");
   end if;

   Update (E, Grad_Weights, Config, State, 1);
   Output2 := Forward (E, IDs1);

   -- Check 2: Update changes weights
   if Element_at (Output1, 1, 1) /= Element_at (Output2, 1, 1) then
      Put_Line ("PASS: Update changes weights");
   else
      Put_Line ("FAIL: Update did not change weights");
   end if;

   Zero_Grad (Grad_Weights, E);

   -- Check 3: Zero_Grad zeroes gradients
   if Element_at (Grad_Weights, 1, 1) = 0.0 then
      Put_Line ("PASS: Zero_Grad zeroes gradients");
   else
      Put_Line ("FAIL: Zero_Grad did not zero gradients");
   end if;

   Save (E, "test_embedding.dat");
   E2      := Load ("test_embedding.dat");
   Output3 := Forward (E2, IDs1);

   -- Check 4: Save/Load round-trip preserves weights
   if Element_at (Output2, 1, 1) = Element_at (Output3, 1, 1) then
      Put_Line ("PASS: Save/Load round-trip preserves weights");
   else
      Put_Line ("FAIL: Save/Load round-trip failed");
   end if;

end Test_Embedding_Training;
