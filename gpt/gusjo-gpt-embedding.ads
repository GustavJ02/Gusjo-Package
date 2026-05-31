with Gusjo.Math;           use Gusjo.Math;
with Gusjo.GPT.Tokenizer;  use Gusjo.GPT.Tokenizer;

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

private

   type Embedding_Layer is record
      Weights   : Matrix;   -- Vocab_Size × Embed_Dim
      Vocab_Size : Positive;
      Embed_Dim  : Positive;
   end record;

end Gusjo.GPT.Embedding;