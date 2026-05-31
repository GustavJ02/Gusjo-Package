with Ada.Text_IO;         use Ada.Text_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Gusjo.GPT.Tokenizer; use Gusjo.GPT.Tokenizer;

procedure Test_Tokenizer is
   T   : BPE_Tokenizer;
   IDs : ID_Vec.Vector;
begin
   -- Step 1: Test Initialize_Tokenizer
   Put_Line ("Initializing tokenizer...");
   Initialize_Tokenizer (T);

   Put_Line ("Vocab size after init: " &
             Natural'Image (Natural (T.Vocab.Length)));
   -- Should print: 256

   Put_Line ("Next_ID after init: " &
             Token_ID'Image (T.Next_ID));
   -- Should print: 256

   -- Spot check: token ID 65 should be "A"
   declare
      Expected : constant Unbounded_String := To_Unbounded_String ("A");
      Got      : constant Unbounded_String := T.Reverse_Vocab (Token_ID (65));
   begin
      if Got = Expected then
         Put_Line ("Byte 65 = 'A': PASS");
      else
         Put_Line ("Byte 65 = 'A': FAIL (got: " & To_String (Got) & ")");
      end if;
   end;

   -- Step 2: Test Read_And_Append_Corpus
   -- First create a tiny test file so we don't need the real corpus
   declare
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, "test_corpus.txt");
      Ada.Text_IO.Put_Line (File, "hello world");
      Ada.Text_IO.Put_Line (File, "hello ada");
      Ada.Text_IO.Close (File);
   end;

   Put_Line ("Reading corpus...");
   Read_And_Append_Corpus ("test_corpus.txt", IDs);

   Put_Line ("ID count after read: " &
             Natural'Image (Natural (IDs.Length)));
   -- "hello world\n" = 12 chars, "hello ada\n" = 10 chars = 22 total

   -- Print first 10 token IDs so we can sanity check
   Put_Line ("First 10 token IDs:");
   for I in IDs.First_Index .. IDs.First_Index + 9 loop
      Put (Token_ID'Image (IDs (I)) & " ");
   end loop;
   New_Line;
   -- Should print: 104 101 108 108 111 32 119 111 114 108
   -- which is:      h   e   l   l   o  sp   w   o   r   l
   declare
      IDs_For_Merge : ID_Vec.Vector;
      T2            : BPE_Tokenizer;
   begin
      Initialize_Tokenizer (T2);
      Read_And_Append_Corpus ("test_corpus.txt", IDs_For_Merge);
      Merge_BPE (T2, IDs_For_Merge, 260);

      Put_Line ("Vocab size after merging: " &
                Natural'Image (Natural (T2.Vocab.Length)));

      Put_Line ("Merge rules learned:");
      for I in 0 .. Natural (T2.Merges.Length) - 1 loop
         declare
            M      : constant Token_Pair := T2.Merges (I);
            New_ID : constant Token_ID   := Token_ID (256 + I);
         begin
            Put_Line ("  [" & Token_ID'Image (New_ID) & "] " &
                      To_String (T2.Reverse_Vocab (M.Left)) &
                      " + " &
                      To_String (T2.Reverse_Vocab (M.Right)) &
                      " => " &
                      To_String (T2.Reverse_Vocab (New_ID)));
         end;
      end loop;
   end;
   -- Step 4: test Encode and Decode
   declare
      T3      : BPE_Tokenizer;
      IDs_E   : ID_Vec.Vector;
      Encoded : ID_Vec.Vector;
   begin
      Initialize_Tokenizer (T3);
      Read_And_Append_Corpus ("test_corpus.txt", IDs_E);
      Merge_BPE (T3, IDs_E, 260);

      -- Encode a known string
      Encoded := Encode (T3, "hello");
      Put ("Encoded 'hello': ");
      for ID of Encoded loop
         Put (Token_ID'Image (ID) & " ");
      end loop;
      New_Line;
      -- With our merges: "hello" => [259] (single token!)

      -- Decode it back
      Put_Line ("Decoded back: " & Decode (T3, Encoded));
      -- Should print: hello

      -- Round-trip check
      if Decode (T3, Encode (T3, "hello world")) = "hello world" then
         Put_Line ("Round-trip 'hello world': PASS");
      else
         Put_Line ("Round-trip 'hello world': FAIL");
      end if;
      -- Step 5: test Save and Load
      Put_Line ("Testing Save/Load...");
      Save (T3, "tokenizer.dat");
      Put_Line ("Saved to tokenizer.dat");
   end;

   -- Load it back into a fresh tokenizer
   declare
      T4      : constant BPE_Tokenizer := Load ("tokenizer.dat");
      Encoded : constant ID_Vec.Vector := Encode (T4, "hello");
   begin
      Put_Line ("Loaded vocab size: " &
                Natural'Image (Natural (T4.Vocab.Length)));
      -- Should match T3: 260

      Put_Line ("Loaded merge count: " &
                Natural'Image (Natural (T4.Merges.Length)));
      -- Should match T3: 4

      if Decode (T4, Encoded) = "hello" then
         Put_Line ("Save/Load round-trip: PASS");
      else
         Put_Line ("Save/Load round-trip: FAIL");
      end if;
   end;

end Test_Tokenizer;