package body Gusjo.GPT.Tokenizer is

   function "<"(Left, Right : Token_Pair) return Boolean is
   begin
      if Left.Left < Right.Left then
         return True;
      elsif Left.Left = Right.Left then
         return Left.Right < Right.Right;
      else
         return False;
      end if;
   end "<";

   procedure Initialize_Tokenizer(T : in out BPE_Tokenizer) is
   begin
      for B in 0 .. 255 loop
         declare
            S : constant Unbounded_String := To_Unbounded_String((1 => Character'Val(B)));
         begin
            T.Vocab.Insert(S, Token_ID(B));
            T.Reverse_Vocab.Insert(Token_ID(B), S);
         end;
      end loop;
      T.Next_ID := 256;
   end Initialize_Tokenizer;

   procedure Read_And_Append_Corpus(Corpus_Path : in String;
                                    IDs         : in out ID_Vec.Vector) is
      File : Ada.Text_IO.File_Type;
   begin
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Corpus_Path);
      exception
         when Ada.Text_IO.Name_Error =>
            raise Gusjo.Internal_Error
            with "Tokenizer: corpus file not found: " & Corpus_Path;

      while not Ada.Text_IO.End_Of_File(File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line(File);
         begin
            for Ch of Line loop
               IDs.Append(Token_ID(Character'Pos(Ch)));
            end loop;
            IDs.Append(Token_ID(10)); -- Newline
         end;
      end loop;
      Ada.Text_IO.Close(File);
   end Read_And_Append_Corpus;

   function Train(Corpus_Path : String;
                  Vocab_Size  : Positive) return BPE_Tokenizer is
      T   : BPE_Tokenizer;
      IDs : ID_Vec.Vector;
   begin
      Initialize_Tokenizer(T);
      Read_And_Append_Corpus(Corpus_Path, IDs);

      return T;
   end Train;

   -- Encode string → token IDs
   function Encode(T    : BPE_Tokenizer;
                   Text : String) return ID_Vec.Vector;

   -- Decode token IDs → string
   function Decode(T   : BPE_Tokenizer;
                   IDs : ID_Vec.Vector) return String;

   -- Save/load (for reuse across runs)
   procedure Save(T : BPE_Tokenizer;
                  Path : String);

   function Load(Path : String) return BPE_Tokenizer;

end Gusjo.GPT.Tokenizer;