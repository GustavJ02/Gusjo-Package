with Gusjo.Math;                use Gusjo.Math;
with Gusjo.GPT.Tokenizer;       use Gusjo.GPT.Tokenizer;
with Gusjo.Math.Optimization;   use Gusjo.Math.Optimization;

package Gusjo.GPT.Embedding is

   type Embedding_Layer is private;

   function Create
     (Vocab_Size : Positive;
      Embed_Dim  : Positive) return Embedding_Layer;

   -- Forward pass: sequence of token IDs → sequence of vectors
   -- Returns matrix of shape Seq_Len × Embed_Dim
   function Forward
     (E   : Embedding_Layer;
      IDs : ID_Vec.Vector) return Matrix;

   -- Initialize weights with small random values
   procedure Initialize (E : in out Embedding_Layer);

   -- Backward: accumulate upstream gradients into Grad_Weights
   -- D_Output is Seq_Len x Embed_Dim; Grad_Weights is Vocab_Size x Embed_Dim
   procedure Backward
     (E            : in     Embedding_Layer;
      IDs          : in     ID_Vec.Vector;
      D_Output     : in     Matrix;
      Grad_Weights : in out Matrix);

   -- Zero the gradient accumulator between batches
   procedure Zero_Grad (Grad_Weights : in out Matrix;
                        E            : in     Embedding_Layer);

   -- Apply one optimizer step to embedding weights
   procedure Update
     (E            : in out Embedding_Layer;
      Grad_Weights : in     Matrix;
      Config       : in     Optimizer_Config;
      State        : in out Optimizer_State;
      Step         : in     Natural);

   -- Persistence
   procedure Save (E : in  Embedding_Layer; Path : in String);
   function  Load (Path : in String) return Embedding_Layer;

private

   type Embedding_Layer is record
      Weights   : Matrix;   -- Vocab_Size × Embed_Dim
      Vocab_Size : Positive;
      Embed_Dim  : Positive;
   end record;

end Gusjo.GPT.Embedding;