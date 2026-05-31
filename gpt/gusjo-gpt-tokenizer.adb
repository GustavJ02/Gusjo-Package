with Ada.Text_IO; use Ada.Text_IO;
with Ada.Strings.Fixed;
with System.Multiprocessors;
with Ada.Environment_Variables;

package body Gusjo.GPT.Tokenizer is

   package Pair_Count_Maps is new Ada.Containers.Ordered_Maps
   (Key_Type     => Token_Pair,
      Element_Type => Natural);

   function Tokenizer_Worker_Count return Positive is
      Default_Count : constant Positive :=
      Positive (System.Multiprocessors.Number_Of_CPUs);
   begin
      if Ada.Environment_Variables.Exists ("GUSJO_TOKENIZER_WORKERS") then
         declare
            Value : constant String :=
            Ada.Strings.Fixed.Trim
               (Ada.Environment_Variables.Value ("GUSJO_TOKENIZER_WORKERS"),
               Ada.Strings.Both);
         begin
            return Positive'Value (Value);
         exception
            when Constraint_Error =>
               null;
         end;
      end if;
      return Default_Count;
   end Tokenizer_Worker_Count;

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
      end;
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

   procedure Merge_BPE (T          : in out BPE_Tokenizer;
                        IDs        : in out ID_Vec.Vector;
                        Vocab_Size : in Positive) is

      Num_Tasks  : constant Positive := Tokenizer_Worker_Count;
      Pair_Counts : Pair_Count_Maps.Map;
      Curr_Size   : Natural := 0;

      -- Access type so tasks can read IDs without copying
      type ID_Vec_Access is access constant ID_Vec.Vector;

      -- --------------------------------------------------------
      --  TASK TYPE 1: Count pairs in a slice of IDs
      -- --------------------------------------------------------
      task type Count_Task is
         entry Start (IDs_Ptr : ID_Vec_Access;
                     First   : Natural;
                     Last    : Natural);
         entry Get_Result (Result : out Pair_Count_Maps.Map);
      end Count_Task;

      task body Count_Task is
         Local_Counts : Pair_Count_Maps.Map;
         IDs_Ref      : ID_Vec_Access;
         F, L         : Natural;
      begin
         accept Start (IDs_Ptr : ID_Vec_Access;
                     First   : Natural;
                     Last    : Natural) do
            IDs_Ref := IDs_Ptr;
            F       := First;
            L       := Last;
         end Start;

         for I in F .. L loop
            declare
               P : constant Token_Pair :=
               (Left  => IDs_Ref (I),
                  Right => IDs_Ref (I + 1));
               C : Natural := 0;
            begin
               if Local_Counts.Contains (P) then
                  C := Local_Counts (P);
               end if;
               Local_Counts.Include (P, C + 1);
            end;
         end loop;

         accept Get_Result (Result : out Pair_Count_Maps.Map) do
            Result := Local_Counts;
         end Get_Result;
      end Count_Task;

      -- --------------------------------------------------------
      --  TASK TYPE 2: Apply a merge to a slice, write to output
      -- --------------------------------------------------------
      task type Apply_Task is
         entry Start (IDs_Ptr  : ID_Vec_Access;
                     First    : Natural;
                     Last     : Natural;
                     Left_ID  : Token_ID;
                     Right_ID : Token_ID;
                     New_ID   : Token_ID);
         entry Get_Result (Result : out ID_Vec.Vector);
      end Apply_Task;

      task body Apply_Task is
         Local_Out        : ID_Vec.Vector;
         IDs_Ref          : ID_Vec_Access;
         F, L             : Natural;
         L_ID, R_ID, N_ID : Token_ID;
      begin
         accept Start (IDs_Ptr  : ID_Vec_Access;
                     First    : Natural;
                     Last     : Natural;
                     Left_ID  : Token_ID;
                     Right_ID : Token_ID;
                     New_ID   : Token_ID) do
            IDs_Ref := IDs_Ptr;
            F       := First;
            L       := Last;
            L_ID    := Left_ID;
            R_ID    := Right_ID;
            N_ID    := New_ID;
         end Start;

         declare
            I : Natural := F;
         begin
            while I <= L loop
               if I < L
               and then IDs_Ref (I)     = L_ID
               and then IDs_Ref (I + 1) = R_ID
               then
                  Local_Out.Append (N_ID);
                  I := I + 2;
               else
                  Local_Out.Append (IDs_Ref (I));
                  I := I + 1;
               end if;
            end loop;
         end;

         accept Get_Result (Result : out ID_Vec.Vector) do
            Result := Local_Out;
         end Get_Result;
      end Apply_Task;

      -- --------------------------------------------------------
      --  Helper: split IDs into N roughly equal chunks
      --  Returns array of (First, Last) pairs
      -- --------------------------------------------------------
      type Chunk is record
         First : Natural;
         Last  : Natural;
      end record;
      type Chunk_Array is array (1 .. Num_Tasks) of Chunk;

      function Make_Chunks (First : Natural;
                           Last  : Natural;
                           N     : Positive) return Chunk_Array is
         Result     : Chunk_Array;
         Total      : constant Natural := Last - First + 1;
         Chunk_Size : constant Natural := (Total + N - 1) / N;
      begin
         for I in 1 .. N loop
            Result (I).First :=
            First + (I - 1) * Chunk_Size;
            Result (I).Last  :=
            Natural'Min (Result (I).First + Chunk_Size - 1, Last);
         end loop;
         return Result;
      end Make_Chunks;

   begin
      -- =========================================================
      --  Main BPE loop
      -- =========================================================
      while Natural (T.Vocab.Length) < Vocab_Size loop

         Curr_Size := Natural (T.Vocab.Length);
         if (Curr_Size mod 100) = 0 then
            Put_Line ("Current Vocab Size:" & Natural'Image (Curr_Size));
         end if;

         -- -------------------------------------------------------
         --  PHASE 1: Parallel pair counting
         -- -------------------------------------------------------
         Pair_Counts.Clear;

         declare
            IDs_Ptr    : constant ID_Vec_Access := IDs'Unchecked_Access;
            -- Each task needs to count up to Last-1 (pairs go I, I+1)
            -- so we split on IDs.First_Index .. IDs.Last_Index - 1
            Chunks     : constant Chunk_Array :=
            Make_Chunks (IDs.First_Index,
                           IDs.Last_Index - 1,
                           Num_Tasks);
            Tasks      : array (1 .. Num_Tasks) of Count_Task;
         begin
            -- Launch all counting tasks
            for T_Idx in 1 .. Num_Tasks loop
               Tasks (T_Idx).Start
               (IDs_Ptr,
                  Chunks (T_Idx).First,
                  Chunks (T_Idx).Last);
            end loop;

            -- Collect and merge partial counts
            for T_Idx in 1 .. Num_Tasks loop
               declare
                  Partial : Pair_Count_Maps.Map;
               begin
                  Tasks (T_Idx).Get_Result (Partial);
                  for Cursor in Partial.Iterate loop
                     declare
                        P        : constant Token_Pair :=
                        Pair_Count_Maps.Key (Cursor);
                        C        : constant Natural :=
                        Pair_Count_Maps.Element (Cursor);
                        Existing : Natural := 0;
                     begin
                        if Pair_Counts.Contains (P) then
                           Existing := Pair_Counts (P);
                        end if;
                        Pair_Counts.Include (P, Existing + C);
                     end;
                  end loop;
               end;
            end loop;
         end;

         exit when Pair_Counts.Is_Empty;

         -- -------------------------------------------------------
         --  Find best pair (single-threaded — fast map scan)
         -- -------------------------------------------------------
         declare
            Best       : Token_Pair;
            Best_Count : Natural := 0;
         begin
            for Cursor in Pair_Counts.Iterate loop
               if Pair_Count_Maps.Element (Cursor) > Best_Count then
                  Best_Count := Pair_Count_Maps.Element (Cursor);
                  Best       := Pair_Count_Maps.Key (Cursor);
               end if;
            end loop;

            declare
               Left_Str : constant Unbounded_String :=
               T.Reverse_Vocab (Best.Left);
               Right_Str : constant Unbounded_String :=
               T.Reverse_Vocab (Best.Right);
               New_Str  : constant Unbounded_String :=
               Left_Str & Right_Str;
               New_ID   : constant Token_ID := T.Next_ID;
            begin
               T.Vocab.Include (New_Str, New_ID);
               T.Reverse_Vocab.Include (New_ID, New_Str);
               T.Merges.Append (Best);
               T.Next_ID := T.Next_ID + 1;

               -- ---------------------------------------------------
               --  PHASE 2: Parallel apply merge
               -- ---------------------------------------------------
               declare
                  IDs_Ptr : constant ID_Vec_Access := IDs'Unchecked_Access;
                  Chunks  : constant Chunk_Array :=
                  Make_Chunks (IDs.First_Index,
                                 IDs.Last_Index,
                                 Num_Tasks);
                  Tasks   : array (1 .. Num_Tasks) of Apply_Task;
                  New_IDs : ID_Vec.Vector;
               begin
                  -- Launch apply tasks
                  for T_Idx in 1 .. Num_Tasks loop
                     Tasks (T_Idx).Start
                     (IDs_Ptr,
                        Chunks (T_Idx).First,
                        Chunks (T_Idx).Last,
                        Best.Left,
                        Best.Right,
                        New_ID);
                  end loop;

                  -- Collect results in order and stitch together
                  for T_Idx in 1 .. Num_Tasks loop
                     declare
                        Partial : ID_Vec.Vector;
                     begin
                        Tasks (T_Idx).Get_Result (Partial);
                        for ID of Partial loop
                           New_IDs.Append (ID);
                        end loop;
                     end;
                  end loop;

                  IDs := New_IDs;
               end;
            end;
         end;

      end loop;
   end Merge_BPE;
   
   function Train(Corpus_Path : String;
                  Vocab_Size  : Positive) return BPE_Tokenizer is
      T   : BPE_Tokenizer;
      IDs : ID_Vec.Vector;
   begin
      Initialize_Tokenizer(T);
      Read_And_Append_Corpus(Corpus_Path, IDs);
      Merge_BPE(T, IDs, Vocab_Size);
      return T;
   end Train;

   -- Encode string → token IDs
   function Encode (T    : BPE_Tokenizer;
                  Text : String) return ID_Vec.Vector is
      IDs : ID_Vec.Vector;
   begin
      -- Step 1: convert every character to its byte ID
      for Ch of Text loop
         IDs.Append (Token_ID (Character'Pos (Ch)));
      end loop;

      -- Step 2: apply each merge rule in priority order
      for I in T.Merges.First_Index .. T.Merges.Last_Index loop
         declare
            M       : constant Token_Pair := T.Merges (I);
            New_ID  : constant Token_ID   := Token_ID (256 + I);
            New_IDs : ID_Vec.Vector;
            J       : Natural := IDs.First_Index;
         begin
            while J <= IDs.Last_Index loop
               if J < IDs.Last_Index
               and then IDs (J)     = M.Left
               and then IDs (J + 1) = M.Right
               then
                  New_IDs.Append (New_ID);
                  J := J + 2;
               else
                  New_IDs.Append (IDs (J));
                  J := J + 1;
               end if;
            end loop;
            IDs := New_IDs;
         end;
      end loop;

      return IDs;
   end Encode;

   -- Decode token IDs → string
   function Decode (T   : BPE_Tokenizer;
                  IDs : ID_Vec.Vector) return String is
      Result : Unbounded_String;
   begin
      for ID of IDs loop
         Result := Result & T.Reverse_Vocab (ID);
      end loop;
      return To_String (Result);
   end Decode;

   -- Convert a single byte to two hex characters e.g. 65 -> "41"
   function Byte_To_Hex (B : Natural) return String is
      Hex_Chars : constant String := "0123456789abcdef";
   begin
      return (1 => Hex_Chars (B / 16 + 1),
            2 => Hex_Chars (B mod 16 + 1));
   end Byte_To_Hex;

   -- Convert an Unbounded_String to its hex representation
   function Str_To_Hex (S : Unbounded_String) return String is
      Raw    : constant String := To_String (S);
      Result : Unbounded_String;
   begin
      for Ch of Raw loop
         Result := Result &
         Byte_To_Hex (Character'Pos (Ch));
      end loop;
      return To_String (Result);
   end Str_To_Hex;

   -- Convert a single hex character to its value 0-15
   function Hex_Char_To_Val (Ch : Character) return Natural is
   begin
      case Ch is
         when '0' .. '9' => return Character'Pos (Ch) - Character'Pos ('0');
         when 'a' .. 'f' => return Character'Pos (Ch) - Character'Pos ('a') + 10;
         when others     => raise Gusjo.Internal_Error
                              with "Invalid hex character: " & Ch;
      end case;
   end Hex_Char_To_Val;

   -- Convert a hex string back to an Unbounded_String
   function Hex_To_Str (Hex : String) return Unbounded_String is
      Result : Unbounded_String;
   begin
      -- Each byte is two hex chars, so step by 2
      declare
         I : Natural := Hex'First;
      begin
         while I <= Hex'Last - 1 loop
            declare
               Hi  : constant Natural := Hex_Char_To_Val (Hex (I));
               Lo  : constant Natural := Hex_Char_To_Val (Hex (I + 1));
               Val : constant Natural := Hi * 16 + Lo;
            begin
               Result := Result & Character'Val (Val);
            end;
            I := I + 2;
         end loop;
      end;
      return Result;
   end Hex_To_Str;

   function Parse_Header_Count (Line : String) return Natural is
   begin
      for I in Line'Range loop
         if Line (I) = ' ' then
            return Natural'Value (Line (I .. Line'Last));
         end if;
      end loop;
      raise Gusjo.Internal_Error with "Malformed header line: " & Line;
   end Parse_Header_Count;


   -- Save/load (for reuse across runs)
   procedure Save (T : BPE_Tokenizer; Path : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);

      -- Write vocab header and entries
      Ada.Text_IO.Put_Line
      (File, "VOCAB " &
         Ada.Strings.Fixed.Trim
            (Natural'Image (Natural (T.Vocab.Length)), Ada.Strings.Both));


      for Cursor in T.Vocab.Iterate loop
         declare
            ID  : constant Token_ID      := Vocab_Map.Element (Cursor);
            Str : constant Unbounded_String := Vocab_Map.Key (Cursor);
         begin
            Ada.Text_IO.Put_Line
            (File,
               Ada.Strings.Fixed.Trim (Token_ID'Image (ID), Ada.Strings.Both)
               & "|" & Str_To_Hex (Str));
         end;
      end loop;

      -- Write merge rules
      Ada.Text_IO.Put_Line
      (File, "MERGES " &
         Ada.Strings.Fixed.Trim
            (Natural'Image (Natural (T.Merges.Length)), Ada.Strings.Both));


      for M of T.Merges loop
         Ada.Text_IO.Put_Line
         (File,
            Ada.Strings.Fixed.Trim (Token_ID'Image (M.Left), Ada.Strings.Both)
            & " " &
            Ada.Strings.Fixed.Trim (Token_ID'Image (M.Right), Ada.Strings.Both));
      end loop;


      Ada.Text_IO.Close (File);
   end Save;

   function Load (Path : String) return BPE_Tokenizer is
      T    : BPE_Tokenizer;
      File : Ada.Text_IO.File_Type;
   begin
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      exception
         when Ada.Text_IO.Name_Error =>
            raise Gusjo.Internal_Error
            with "Tokenizer: save file not found: " & Path;
      end;

      -- Read vocab header e.g. "VOCAB 260"
      declare
         Header     : constant String  := Ada.Text_IO.Get_Line (File);
         Vocab_Size : constant Natural := Parse_Header_Count (Header);
      begin
         for I in 1 .. Vocab_Size loop
            declare
               Line    : constant String := Ada.Text_IO.Get_Line (File);
               Sep     : Natural         := 0;
            begin
               -- Find the '|' separator
               for J in Line'Range loop
                  if Line (J) = '|' then
                     Sep := J;
                     exit;
                  end if;
               end loop;

               declare
                  ID : constant Token_ID :=
                     Token_ID'Value (Ada.Strings.Fixed.Trim
                        (Line (Line'First .. Sep - 1),
                        Ada.Strings.Both));
                  Str : constant Unbounded_String :=
                  Hex_To_Str (Line (Sep + 1 .. Line'Last));
               begin
                  T.Vocab.Include (Str, ID);
                  T.Reverse_Vocab.Include (ID, Str);
                  if ID >= T.Next_ID then
                     T.Next_ID := ID + 1;
                  end if;
               end;
            end;
         end loop;
      end;

      -- Read merges header e.g. "MERGES 4"
      declare
         Header      : constant String  := Ada.Text_IO.Get_Line (File);
         Merge_Count : constant Natural := Parse_Header_Count (Header);
      begin
         for I in 1 .. Merge_Count loop
            declare
               Line  : constant String := Ada.Text_IO.Get_Line (File);
               Space : Natural         := 0;
            begin
               for J in Line'Range loop
                  if Line (J) = ' ' then
                     Space := J;
                     exit;
                  end if;
               end loop;

               T.Merges.Append
                  ((Left  => Token_ID'Value (Ada.Strings.Fixed.Trim
                                 (Line (Line'First .. Space - 1),
                                 Ada.Strings.Both)),
                     Right => Token_ID'Value (Ada.Strings.Fixed.Trim
                                 (Line (Space + 1 .. Line'Last),
                                 Ada.Strings.Both))));
            end;
         end loop;
      end;

      Ada.Text_IO.Close (File);
      return T;
   end Load;

end Gusjo.GPT.Tokenizer;