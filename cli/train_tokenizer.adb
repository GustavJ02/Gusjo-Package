with Ada.Text_IO;             use Ada.Text_IO;
with Gusjo.GPT.Tokenizer;     use Gusjo.GPT.Tokenizer;
with Ada.Command_Line;        use Ada.Command_Line;
with Ada.Strings.Unbounded;   use Ada.Strings.Unbounded;

procedure Train_Tokenizer is
   use Ada.Command_Line;
   use Ada.Strings.Unbounded;

   T                : BPE_Tokenizer;
   Arg_Count        : constant Natural := Argument_Count;
   Text_File_Path   : Unbounded_String;
   Output_File_Path : Unbounded_String;
   Vocab_Size       : Natural;
begin
   if Arg_Count not in 2 .. 3 then
      Put_Line ("Wrong number of arguments. (Expected 2 or 3, got" &
                Arg_Count'Image & ")");
      Put_Line ("USAGE: " & Command_Name &
                " <Path to text> <Vocab Size> [<Output File>]");
      return;
   end if;

   Text_File_Path := To_Unbounded_String (Argument (1));

   begin
      Vocab_Size := Natural'Value (Argument (2));
   exception
      when others =>
         Put_Line ("Failed to parse '" & Argument (2) & "' as Integer > 0");
         return;
   end;

   if Vocab_Size < 256 then
      Put_Line ("Vocab size must be larger than 255. Got" &
                Natural'Image (Vocab_Size));
      return;
   end if;

   Put_Line ("Training on corpus: " & To_String (Text_File_Path));
   T := Train (To_String (Text_File_Path), Vocab_Size);
   Put_Line ("Vocab size: "    & Natural'Image (Natural (T.Vocab.Length)));
   Put_Line ("Merges learned: " & Natural'Image (Natural (T.Merges.Length)));

   if Arg_Count = 3 then
      Output_File_Path := To_Unbounded_String (Argument (3));
   else
      Output_File_Path := To_Unbounded_String ("wiki_tokenizer.dat");
   end if;

   Save (T, To_String (Output_File_Path));
   Put_Line ("Saved to '" & To_String (Output_File_Path) & "'");

   -- Spot check a domain-specific term
   declare
      Term    : constant String          := "aerodynamic";
      Encoded : constant ID_Vec.Vector   := Encode (T, Term);
      Decoded : constant String          := Decode (T, Encoded);
   begin
      Put ("'" & Term & "' encodes to " &
           Natural'Image (Natural (Encoded.Length)) & " token(s): ");
      for ID of Encoded loop
         Put (Token_ID'Image (ID) & " ");
      end loop;
      New_Line;
      Put_Line ("Decoded: " & Decoded);
   end;
end Train_Tokenizer;