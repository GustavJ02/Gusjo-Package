with Gusjo.Math.Linalg;                   use Gusjo.Math.Linalg;
with Gusjo.Math.Optimization;             use Gusjo.Math.Optimization;
with Ada.Numerics.Elementary_Functions;   use Ada.Numerics.Elementary_Functions;
with Ada.Text_IO;                         use Ada.Text_IO;
with Ada.Strings;
with Ada.Strings.Fixed;

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

   procedure Backward
     (E            : in     Embedding_Layer;
      IDs          : in     ID_Vec.Vector;
      D_Output     : in     Matrix;
      Grad_Weights : in out Matrix) is
   begin
      for Pos in IDs.First_Index .. IDs.Last_Index loop
         declare
            Row   : constant Positive := Pos - IDs.First_Index + 1;
            Token : constant Positive :=
              Positive (Natural (ID_Vec.Element (IDs, Pos))) + 1;
         begin
            for Col in 1 .. E.Embed_Dim loop
               Element_at (Grad_Weights, Token, Col,
                           Element_at (Grad_Weights, Token, Col) +
                           Element_at (D_Output, Row, Col));
            end loop;
         end;
      end loop;
   end Backward;

   procedure Zero_Grad (Grad_Weights : in out Matrix;
                        E            : in     Embedding_Layer) is
   begin
      for R in 1 .. E.Vocab_Size loop
         for C in 1 .. E.Embed_Dim loop
            Element_at (Grad_Weights, R, C, 0.0);
         end loop;
      end loop;
   end Zero_Grad;

   procedure Update
     (E            : in out Embedding_Layer;
      Grad_Weights : in     Matrix;
      Config       : in     Optimizer_Config;
      State        : in out Optimizer_State;
      Step         : in     Natural) is
   begin
      Optimize_Step (E.Weights, Grad_Weights, Config, State, Step);
   end Update;

   procedure Save (E : in Embedding_Layer; Path : in String) is
      File : File_Type;
   begin
      Create (File, Out_File, Path);
      Put_Line (File,
                "EMBEDDING " &
                Ada.Strings.Fixed.Trim (Natural'Image (E.Vocab_Size), Ada.Strings.Both) &
                " " &
                Ada.Strings.Fixed.Trim (Natural'Image (E.Embed_Dim), Ada.Strings.Both));
      for R in 1 .. E.Vocab_Size loop
         for C in 1 .. E.Embed_Dim loop
            if C > 1 then
               Put (File, " ");
            end if;
            Put (File,
                 Ada.Strings.Fixed.Trim (
                   Long_Float'Image (Long_Float (Element_at (E.Weights, R, C))),
                   Ada.Strings.Both));
         end loop;
         New_Line (File);
      end loop;
      Close (File);
   end Save;

   function Load (Path : in String) return Embedding_Layer is
      package Float_IO is new Ada.Text_IO.Float_IO (Float);
      File       : File_Type;
      E          : Embedding_Layer;
      Line       : String (1 .. 512);
      Last       : Natural;
      Val        : Float;
      Vocab_Size : Positive;
      Embed_Dim  : Positive;
   begin
      begin
         Open (File, In_File, Path);
      exception
         when Name_Error =>
            raise Gusjo.Internal_Error with "Cannot open embedding file: " & Path;
      end;
      Get_Line (File, Line, Last);
      declare
         Header : constant String := Line (1 .. Last);
         -- "EMBEDDING " is 10 chars; Vocab_Size starts at index 11
         Sp_Pos : constant Natural :=
           Ada.Strings.Fixed.Index (Header, " ", 11);
      begin
         Vocab_Size := Positive'Value (Header (11 .. Sp_Pos - 1));
         Embed_Dim  := Positive'Value (Header (Sp_Pos + 1 .. Header'Last));
      end;
      E.Vocab_Size := Vocab_Size;
      E.Embed_Dim  := Embed_Dim;
      E.Weights    := Zeros (Vocab_Size, Embed_Dim);
      for R in 1 .. Vocab_Size loop
         for C in 1 .. Embed_Dim loop
            Float_IO.Get (File, Val);
            Element_at (E.Weights, R, C, Val);
         end loop;
      end loop;
      Close (File);
      return E;
   end Load;

end Gusjo.GPT.Embedding;