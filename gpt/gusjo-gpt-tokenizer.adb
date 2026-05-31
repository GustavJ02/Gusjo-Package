with Ada.Text_IO; use Ada.Text_IO;
with Ada.Strings.Fixed;
with System.Multiprocessors;
with Ada.Environment_Variables;
with Ada.Calendar; use Ada.Calendar;
with Ada.Containers.Hashed_Maps;
with Ada.Containers.Vectors;

package body Gusjo.GPT.Tokenizer is

   function Hash_Token_Pair (P : Token_Pair) return Ada.Containers.Hash_Type is
      use type Ada.Containers.Hash_Type;  -- makes *, xor visible
      A : constant Ada.Containers.Hash_Type :=
      Ada.Containers.Hash_Type (P.Left);
      B : constant Ada.Containers.Hash_Type :=
      Ada.Containers.Hash_Type (P.Right);
   begin
      return (A * 2654435761) xor (B * 2246822519);
   end Hash_Token_Pair;


   function Token_Pair_Equal (A, B : Token_Pair) return Boolean is
   begin
      return A.Left = B.Left and then A.Right = B.Right;
   end Token_Pair_Equal;

   package Pair_Count_Maps is new Ada.Containers.Hashed_Maps
   (Key_Type        => Token_Pair,
      Element_Type    => Natural,
      Hash            => Hash_Token_Pair,
      Equivalent_Keys => Token_Pair_Equal);

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

      -- --------------------------------------------------------
      --  Position index: for each pair, where it occurs in IDs
      --  Count is free — just the length of the position vector
      -- --------------------------------------------------------
      package Position_Vec is new Ada.Containers.Vectors
        (Index_Type   => Natural,
         Element_Type => Natural);

      use type Position_Vec.Vector;   -- makes "=" visible for Element_Type
      package Position_Maps is new Ada.Containers.Hashed_Maps
      (Key_Type        => Token_Pair,
         Element_Type    => Position_Vec.Vector,
         Hash            => Hash_Token_Pair,
         Equivalent_Keys => Token_Pair_Equal);

      -- At the top of Merge_BPE declarations, after Position_Maps:
      Num_Tasks : constant Positive := Tokenizer_Worker_Count;

      type ID_Vec_Access is access constant ID_Vec.Vector;

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
            Result (I).First := First + (I - 1) * Chunk_Size;
            Result (I).Last  :=
            Natural'Min (Result (I).First + Chunk_Size - 1, Last);
         end loop;
         return Result;
      end Make_Chunks;

      -- Task: compact a slice (remove sentinels) and build local index
      task type Compact_And_Index_Task is
         entry Start (IDs_Ptr : ID_Vec_Access;
                     First   : Natural;
                     Last    : Natural;
                     Del     : Token_ID);
         entry Get_Result (Compacted : out ID_Vec.Vector;
                           Local_Idx : out Position_Maps.Map);
      end Compact_And_Index_Task;

      task body Compact_And_Index_Task is
         My_IDs : ID_Vec.Vector;      -- renamed from Local_IDs
         My_Idx : Position_Maps.Map;  -- renamed from Local_Idx
         IDs_Ref   : ID_Vec_Access;
         F, L      : Natural;
         Del_Val   : Token_ID;
      begin
         accept Start (IDs_Ptr : ID_Vec_Access;
                     First   : Natural;
                     Last    : Natural;
                     Del     : Token_ID) do
            IDs_Ref := IDs_Ptr;
            F       := First;
            L       := Last;
            Del_Val := Del;
         end Start;
         for I in F .. L loop
            if IDs_Ref (I) /= Del_Val then
               My_IDs.Append (IDs_Ref (I));
            end if;
         end loop;

         for I in My_IDs.First_Index .. My_IDs.Last_Index - 1 loop
            declare
               P : constant Token_Pair :=
               (Left  => My_IDs (I),
                  Right => My_IDs (I + 1));
            begin
               if not My_Idx.Contains (P) then
                  My_Idx.Insert (P, Position_Vec.Empty_Vector);
               end if;
               My_Idx (P).Append (I);
            end;
         end loop;

         accept Get_Result (Compacted : out ID_Vec.Vector;
                           Local_Idx : out Position_Maps.Map) do
            Compacted := My_IDs;   -- now unambiguous
            Local_Idx := My_Idx;   -- now unambiguous
         end Get_Result;
      end Compact_And_Index_Task;

      Positions : Position_Maps.Map;
      Curr_Size : Natural := 0;

      -- Timing accumulators
      T_Build_Total    : Duration := 0.0;
      T_Best_Total     : Duration := 0.0;
      T_Update_Total   : Duration := 0.0;
      T_Compact_Total  : Duration := 0.0;
      T_Start          : Time;

      -- Sentinel value marking a deleted slot in IDs
      -- Token_ID'Last is safe since we never legitimately assign it
      Deleted : constant Token_ID := Token_ID'Last;

      -- --------------------------------------------------------
      --  Add a position to the index for a given pair
      -- --------------------------------------------------------
      procedure Add_Position (Pair : Token_Pair; Pos : Natural) is
      begin
         if not Positions.Contains (Pair) then
            Positions.Insert (Pair, Position_Vec.Empty_Vector);
         end if;
         Positions (Pair).Append (Pos);
      end Add_Position;

      -- --------------------------------------------------------
      --  Remove a specific position from the index for a pair
      --  Deletes the pair entry entirely if no positions remain
      -- --------------------------------------------------------
      procedure Remove_Position (Pair : Token_Pair; Pos : Natural) is
      begin
         if not Positions.Contains (Pair) then
            return;
         end if;

         -- Phase 1: remove the position from the vector
         -- Do this in its own scope so the renames alias is gone before
         -- we potentially delete the map entry
         declare
            Vec       : Position_Vec.Vector renames Positions (Pair);
            Found_Idx : Integer := Position_Vec.No_Index;
         begin
            for I in Vec.First_Index .. Vec.Last_Index loop
               if Vec (I) = Pos then
                  Found_Idx := I;
                  exit;
               end if;
            end loop;
            if Found_Idx /= Position_Vec.No_Index then
               Vec.Delete (Found_Idx);
            end if;
         end;  -- <-- renames alias dies here, Positions is free to modify

         -- Phase 2: now safe to delete the map entry if vector is empty
         if Positions.Contains (Pair)
         and then Positions (Pair).Is_Empty
         then
            Positions.Delete (Pair);
         end if;
      end Remove_Position;


      -- --------------------------------------------------------
      --  Build position index from scratch
      --  Called once at the start — O(n) where n = IDs.Length
      -- --------------------------------------------------------
      procedure Build_Position_Index is
      begin
         Positions.Clear;
         for I in IDs.First_Index .. IDs.Last_Index - 1 loop
            Add_Position
              ((Left => IDs (I), Right => IDs (I + 1)), I);
         end loop;
      end Build_Position_Index;

      -- --------------------------------------------------------
      --  Find the pair with the highest occurrence count
      --  O(number of unique pairs) — much smaller than IDs.Length
      -- --------------------------------------------------------
      function Find_Best return Token_Pair is
         Best       : Token_Pair;
         Best_Count : Natural := 0;
      begin
         for Cursor in Positions.Iterate loop
            declare
               Count : constant Natural :=
                 Natural (Position_Maps.Element (Cursor).Length);
            begin
               if Count > Best_Count then
                  Best_Count := Count;
                  Best       := Position_Maps.Key (Cursor);
               end if;
            end;
         end loop;
         return Best;
      end Find_Best;

   begin
      -- =========================================================
      --  Build the position index once before the main loop
      -- =========================================================
      T_Start := Clock;
      Build_Position_Index;
      T_Build_Total := T_Build_Total + (Clock - T_Start);
      Put_Line ("Index built. Unique pairs: " &
                Natural'Image (Natural (Positions.Length)));

      -- =========================================================
      --  Main BPE loop
      -- =========================================================
      while Natural (T.Vocab.Length) < Vocab_Size loop

         Curr_Size := Natural (T.Vocab.Length);
         if (Curr_Size mod 100) = 0 then
            Put_Line ("Current Vocab Size:" & Natural'Image (Curr_Size));
         end if;

         exit when Positions.Is_Empty;

         -- -------------------------------------------------------
         --  Find best pair — O(unique pairs), not O(corpus size)
         -- -------------------------------------------------------
         T_Start := Clock;
         declare
            Best    : constant Token_Pair := Find_Best;
            New_ID  : constant Token_ID   := T.Next_ID;
            New_Str : constant Unbounded_String :=
              T.Reverse_Vocab (Best.Left) & T.Reverse_Vocab (Best.Right);
         begin
            T_Best_Total := T_Best_Total + (Clock - T_Start);

            -- Register new token
            T.Vocab.Include (New_Str, New_ID);
            T.Reverse_Vocab.Include (New_ID, New_Str);
            T.Merges.Append (Best);
            T.Next_ID := T.Next_ID + 1;

            -- -------------------------------------------------------
            --  Incremental index update
            --  Only touch positions affected by this merge
            --  O(occurrences of Best) instead of O(corpus size)
            -- -------------------------------------------------------
            T_Start := Clock;
            declare
               -- Copy positions before we start modifying the index
               -- (iterating while modifying is unsafe)
               Best_Positions : constant Position_Vec.Vector :=
                 Positions (Best);
            begin
               -- Remove the merged pair from the index entirely
               Positions.Delete (Best);

               for K in Best_Positions.First_Index ..
                        Best_Positions.Last_Index loop
                  declare
                     Pos : constant Natural := Best_Positions (K);
                  begin
                     -- Guard: skip if this slot was already consumed
                     -- by an adjacent merge earlier in this loop
                     if IDs (Pos) /= Deleted
                       and then Pos < IDs.Last_Index
                       and then IDs (Pos)     = Best.Left
                       and then IDs (Pos + 1) = Best.Right
                     then
                        -- Fix left-neighbour pair
                        -- Old pair: (IDs(Pos-1), Best.Left)  disappears
                        -- New pair: (IDs(Pos-1), New_ID)     appears
                        if Pos > IDs.First_Index
                          and then IDs (Pos - 1) /= Deleted
                        then
                           Remove_Position
                             ((Left  => IDs (Pos - 1),
                               Right => Best.Left),
                              Pos - 1);
                           Add_Position
                             ((Left  => IDs (Pos - 1),
                               Right => New_ID),
                              Pos - 1);
                        end if;

                        -- Fix right-neighbour pair
                        -- Old pair: (Best.Right, IDs(Pos+2))  disappears
                        -- New pair: (New_ID,     IDs(Pos+2))  appears
                        -- Note: Pos+1 will become Deleted, so
                        -- the new pair sits at Pos, not Pos+1
                        if Pos + 2 <= IDs.Last_Index
                          and then IDs (Pos + 2) /= Deleted
                        then
                           Remove_Position
                             ((Left  => Best.Right,
                               Right => IDs (Pos + 2)),
                              Pos + 1);
                           Add_Position
                             ((Left  => New_ID,
                               Right => IDs (Pos + 2)),
                              Pos);
                        end if;

                        -- Apply merge: write New_ID at Pos,
                        -- mark Pos+1 as deleted
                        IDs (Pos)     := New_ID;
                        IDs (Pos + 1) := Deleted;
                     end if;
                  end;
               end loop;
            end;
            T_Update_Total := T_Update_Total + (Clock - T_Start);

            -- -------------------------------------------------------
            --  Compact: remove deleted slots and rebuild positions
            --  for affected pairs so indices stay valid
            -- -------------------------------------------------------
            T_Start := Clock;
            declare
               IDs_Ptr         : constant ID_Vec_Access := IDs'Unchecked_Access;
               Chunks          : constant Chunk_Array :=
               Make_Chunks (IDs.First_Index, IDs.Last_Index, Num_Tasks);
               Tasks           : array (1 .. Num_Tasks) of Compact_And_Index_Task;
               New_IDs         : ID_Vec.Vector;
               Chunk_End_Pos   : array (1 .. Num_Tasks) of Natural :=
               (others => 0);
            begin
               New_IDs.Reserve_Capacity (IDs.Length);
               Positions.Clear;

               -- Launch all tasks
               for T_Idx in 1 .. Num_Tasks loop
                  Tasks (T_Idx).Start
                  (IDs_Ptr,
                     Chunks (T_Idx).First,
                     Chunks (T_Idx).Last,
                     Deleted);
               end loop;

               -- Collect results in order, tracking where each chunk ends
               for T_Idx in 1 .. Num_Tasks loop
                  declare
                     Compacted : ID_Vec.Vector;
                     Local_Idx : Position_Maps.Map;
                     Offset    : constant Natural := Natural (New_IDs.Length);
                  begin
                     Tasks (T_Idx).Get_Result (Compacted, Local_Idx);

                     -- Stitch IDs
                     for ID of Compacted loop
                        New_IDs.Append (ID);
                     end loop;

                     -- Record where this chunk ends in New_IDs
                     Chunk_End_Pos (T_Idx) := Natural (New_IDs.Length) - 1;

                     -- Merge local index into global with offset adjustment
                     for Cursor in Local_Idx.Iterate loop
                        declare
                           P   : constant Token_Pair   := Position_Maps.Key (Cursor);
                           Vec : constant Position_Vec.Vector :=
                           Position_Maps.Element (Cursor);
                        begin
                           if not Positions.Contains (P) then
                              Positions.Insert (P, Position_Vec.Empty_Vector);
                           end if;
                           for Pos of Vec loop
                              Positions (P).Append (Pos + Offset);
                           end loop;
                        end;
                     end loop;
                  end;
               end loop;

               -- Fix boundary pairs: each chunk boundary has one pair
               -- that neither task could see (last elem of chunk N, first of N+1)
               for T_Idx in 1 .. Num_Tasks - 1 loop
                  declare
                     Boundary : constant Natural := Chunk_End_Pos (T_Idx);
                  begin
                     if Boundary >= New_IDs.First_Index
                     and then Boundary < New_IDs.Last_Index
                     then
                        declare
                           P : constant Token_Pair :=
                           (Left  => New_IDs (Boundary),
                              Right => New_IDs (Boundary + 1));
                        begin
                           if not Positions.Contains (P) then
                              Positions.Insert (P, Position_Vec.Empty_Vector);
                           end if;
                           Positions (P).Append (Boundary);
                        end;
                     end if;
                  end;
               end loop;

               ID_Vec.Move (Target => IDs, Source => New_IDs);
            end;
            T_Compact_Total := T_Compact_Total + (Clock - T_Start);
         end;
      end loop;

      -- =========================================================
      --  Timing report
      -- =========================================================
      declare
         Total : constant Duration :=
           T_Build_Total + T_Best_Total +
           T_Update_Total + T_Compact_Total;

         function Pct (Part : Duration) return String is
            P : constant Float := Float (Part) / Float (Total) * 100.0;
         begin
            return Natural'Image (Natural (P)) & "%";
         end Pct;
      begin
         Put_Line ("=== Timing Breakdown ===");
         Put_Line ("Build index: " & Duration'Image (T_Build_Total)   &
                   "s  (" & Pct (T_Build_Total)   & ")");
         Put_Line ("Find best:   " & Duration'Image (T_Best_Total)    &
                   "s  (" & Pct (T_Best_Total)    & ")");
         Put_Line ("Update idx:  " & Duration'Image (T_Update_Total)  &
                   "s  (" & Pct (T_Update_Total)  & ")");
         Put_Line ("Compact:     " & Duration'Image (T_Compact_Total) &
                   "s  (" & Pct (T_Compact_Total) & ")");
         Put_Line ("Total:       " & Duration'Image (Total) & "s");
      end;

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