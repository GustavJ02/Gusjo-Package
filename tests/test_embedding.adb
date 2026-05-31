with Gusjo.GPT.Tokenizer;  use Gusjo.GPT.Tokenizer;
with Gusjo.GPT.Embedding;  use Gusjo.GPT.Embedding;
with Gusjo.Math.Linalg;    use Gusjo.Math.Linalg;
with Gusjo.Math;           use Gusjo.Math;

with Ada.Text_IO;          use Ada.Text_IO;

procedure Test_Embedding is
   Tok : constant BPE_Tokenizer := Load ("wiki_tokenizer.dat");
   E   : Embedding_Layer        := Create
            (Vocab_Size => 8000,
             Embed_Dim  => 64);
   IDs : constant ID_Vec.Vector := Encode (Tok, "hello world");
begin
   Initialize (E);  -- weights set FIRST

   declare
      Output : constant Matrix := Forward (E, IDs);  -- uses initialized weights
   begin
      Put_Line ("Input length:  " & Natural'Image (Natural (IDs.Length)));
      Put_Line ("Output rows:   " & Natural'Image (Rows (Output)));
      Put_Line ("Output cols:   " & Natural'Image (Cols (Output)));

      declare
         IDs2 : constant ID_Vec.Vector := Encode (Tok, "hello world");
         Out2 : constant Matrix        := Forward (E, IDs2);
      begin
         if Element_at (Output, 1, 1) = Element_at (Out2, 1, 1) then
            Put_Line ("Deterministic: PASS");
         else
            Put_Line ("Deterministic: FAIL");
         end if;
      end;
   end;
end Test_Embedding;