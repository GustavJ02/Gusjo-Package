with Gusjo.Math.Linalg;                   use Gusjo.Math.Linalg;
with Ada.Numerics.Elementary_Functions;   use Ada.Numerics.Elementary_Functions;

package body Gusjo.GPT.Embedding is

   function Create(Vocab_Size : Positive;
                   Embed_Dim  : Positive) return Embedding_Layer is
      Layer: Embedding_Layer;
   begin
      Layer.Vocab_Size := Vocab_Size;
      Layer.Embed_Dim := Embed_Dim;
      Layer.Weights := Gusjo.Math.Linalg.Zeros(Vocab_Size, Embed_Dim);

      return Layer;
   end Create;

   -- Forward pass: sequence of token IDs → sequence of vectors
   -- Returns matrix of shape Seq_Len × Embed_Dim
   function Forward (E   : Embedding_Layer;
                     IDs : ID_Vec.Vector) return Matrix
   is
      Seq_Len : constant Positive := Positive (Natural (IDs.Length));
      Result  : constant Matrix   := Zeros (Seq_Len, E.Embed_Dim);
   begin
      for Pos in IDs.First_Index .. IDs.Last_Index loop
         declare
            Row   : constant Positive := Pos - IDs.First_Index + 1;
            Token : constant Positive :=
            Positive (Natural (ID_Vec.Element (IDs, Pos))) + 1;
         begin
            for Col in 1 .. E.Embed_Dim loop
               Element_at (Result, Row, Col,
                           Element_at (E.Weights, Token, Col));
            end loop;
         end;
      end loop;
      return Result;
   end Forward;


   -- Initialize weights with small random values
   procedure Initialize (E : in out Embedding_Layer) is
      Scale : constant Float := 1.0 / Sqrt(Float (E.Embed_Dim));
   begin
      Fill_Random_Uniform(E.Weights, -Scale, Scale);
   end Initialize;
end Gusjo.GPT.Embedding;