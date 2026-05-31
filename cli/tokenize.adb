with Ada.Text_IO;           use Ada.Text_IO;
with Ada.Command_Line;      use Ada.Command_Line;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Gusjo.GPT.Tokenizer;   use Gusjo.GPT.Tokenizer;

procedure Tokenize is
   Arg_Count : constant Natural := Argument_Count;
begin
   if Arg_Count /= 2 then
      Put_Line ("Wrong number of arguments. (Expected 2, got" &
                Arg_Count'Image & ")");
      Put_Line ("USAGE: " & Command_Name &
                " <Path to tokenizer.dat> <Text to tokenize>");
      return;
   end if;

   declare
      Tokenizer_Path : constant String := Argument (1);
      Input_Text     : constant String := Argument (2);
      T              : constant BPE_Tokenizer := Load (Tokenizer_Path);
      IDs            : constant ID_Vec.Vector := Encode (T, Input_Text);
   begin
      Put_Line ("Tokenizer:  " & Tokenizer_Path);
      Put_Line ("Input:      " & Input_Text);
      Put_Line ("Token count:" & Natural'Image (Natural (IDs.Length)));
      New_Line;

      -- Print each token as [text] with its ID underneath
      for Pos in IDs.First_Index .. IDs.Last_Index loop
         declare
            ID  : constant Token_ID      := ID_Vec.Element (IDs, Pos);
            Tok : constant String        := Decode (T, ID);
         begin
            -- Print token text, replacing space with [space] for clarity
            if Tok = " " then
               Put ("[space]");
            elsif Tok = (1 => ASCII.LF) then
               Put ("[newline]");
            elsif Tok = (1 => ASCII.HT) then
               Put ("[tab]");
            else
               Put ("[" & Tok & "]");
            end if;
         end;
      end loop;
      New_Line;
      New_Line;

      -- Second pass: print IDs on a second line for reference
      Put ("IDs:  ");
      for Pos in IDs.First_Index .. IDs.Last_Index loop
         declare
            ID : constant Token_ID := ID_Vec.Element (IDs, Pos);
         begin
            Put (Ada.Strings.Fixed.Trim
                   (Token_ID'Image (ID), Ada.Strings.Both) & " ");
         end;
      end loop;
      New_Line;
   end;
end Tokenize;