with Ada.Text_IO; use Ada.Text_IO;
with Ada.Strings.Fixed;
with Ada.Calendar; use Ada.Calendar;
with Ada.Containers.Hashed_Maps;
with Ada.Containers.Vectors;

package body Gusjo.GPT.Tokenizer is

   function Hash_Token_Pair (P : Token_Pair) return Ada.Containers.Hash_Type is
      use type Ada.Containers.Hash_Type;
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

   procedure Initialize_Tokenizer (T : in out BPE_Tokenizer) is
   begin
      for B in 0 .. 255 loop
         declare
            S : constant Unbounded_String :=
              To_Unbounded_String ((1 => Character'Val (B)));
         begin
            T.Vocab.Insert (S, Token_ID (B));
            T.Reverse_Vocab.Insert (Token_ID (B), S);
         end;
      end loop;
      T.Next_ID := 256;
   end Initialize_Tokenizer;

   procedure Read_And_Append_Corpus (Corpus_Path : in String;
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
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            for Ch of Line loop
               IDs.Append (Token_ID (Character'Pos (Ch)));
            end loop;
            IDs.Append (Token_ID (10));
         end;
      end loop;
      Ada.Text_IO.Close (File);
   end Read_And_Append_Corpus;

   procedure Merge_BPE (T          : in out BPE_Tokenizer;
                        IDs        : in out ID_Vec.Vector;
                        Vocab_Size : in Positive) is

      -- --------------------------------------------------------
      --  Pool-backed linked list: O(1) neighbor lookup and
      --  deletion by pointer relinking — no compaction needed.
      --  Prev/Next use -1 as "no neighbour" sentinel.
      -- --------------------------------------------------------
      type Node is record
         ID   : Token_ID;
         Prev : Integer;
         Next : Integer;
      end record;

      type Node_Array is array (Natural range <>) of Node;
      type Node_Array_Access is access Node_Array;

      -- --------------------------------------------------------
      --  Position index: pair -> pool indices of left nodes.
      --  Pair_Counts tracks valid (non-stale) count separately
      --  so Remove_Position is O(1) — no linear scan needed.
      --  Stale entries stay in position vectors and are skipped
      --  by the guard during occurrence iteration.
      -- --------------------------------------------------------
      package Position_Vec is new Ada.Containers.Vectors
        (Index_Type   => Natural,
         Element_Type => Natural);

      use type Position_Vec.Vector;

      package Position_Maps is new Ada.Containers.Hashed_Maps
        (Key_Type        => Token_Pair,
         Element_Type    => Position_Vec.Vector,
         Hash            => Hash_Token_Pair,
         Equivalent_Keys => Token_Pair_Equal);

      package Pair_Count_Maps is new Ada.Containers.Hashed_Maps
        (Key_Type        => Token_Pair,
         Element_Type    => Natural,
         Hash            => Hash_Token_Pair,
         Equivalent_Keys => Token_Pair_Equal);

      Pool_Size   : constant Natural := Natural (IDs.Length);
      Pool        : Node_Array_Access;
      Positions   : Position_Maps.Map;
      Pair_Counts : Pair_Count_Maps.Map;

      procedure Add_Position (Pair : Token_Pair; Pos : Natural) is
      begin
         if not Positions.Contains (Pair) then
            Positions.Insert (Pair, Position_Vec.Empty_Vector);
            Pair_Counts.Insert (Pair, 0);
         end if;
         Positions (Pair).Append (Pos);
         Pair_Counts (Pair) := Pair_Counts (Pair) + 1;
      end Add_Position;

      -- O(1): decrement the valid count for Pair; the stale pool
      -- index stays in the vector and is filtered by the guard
      -- when the pair is later iterated.
      procedure Remove_Position (Pair : Token_Pair) is
      begin
         if not Pair_Counts.Contains (Pair) then
            return;
         end if;
         if Pair_Counts (Pair) > 0 then
            Pair_Counts (Pair) := Pair_Counts (Pair) - 1;
         end if;
         if Pair_Counts (Pair) = 0 then
            Pair_Counts.Delete (Pair);
            Positions.Delete (Pair);
         end if;
      end Remove_Position;

      procedure Build_Position_Index is
      begin
         Positions.Clear;
         Pair_Counts.Clear;
         if Pool_Size >= 2 then
            for I in 0 .. Pool_Size - 2 loop
               Add_Position
                 ((Left => Pool (I).ID, Right => Pool (I + 1).ID), I);
            end loop;
         end if;
      end Build_Position_Index;

      function Find_Best return Token_Pair is
         Best       : Token_Pair;
         Best_Count : Natural := 0;
      begin
         for Cursor in Pair_Counts.Iterate loop
            declare
               Count : constant Natural := Pair_Count_Maps.Element (Cursor);
            begin
               if Count > Best_Count then
                  Best_Count := Count;
                  Best       := Pair_Count_Maps.Key (Cursor);
               end if;
            end;
         end loop;
         return Best;
      end Find_Best;

   begin
      if Pool_Size < 2 then
         Put_Line ("=== Timing Breakdown ===");
         Put_Line ("Total:        0.000000000s");
         return;
      end if;

      Pool := new Node_Array (0 .. Pool_Size - 1);
      for I in 0 .. Pool_Size - 1 loop
         Pool (I) :=
           (ID   => IDs (IDs.First_Index + I),
            Prev => (if I = 0 then -1 else Integer (I) - 1),
            Next => (if I = Pool_Size - 1 then -1 else Integer (I) + 1));
      end loop;

      Build_Position_Index;
      while Natural (T.Vocab.Length) < Vocab_Size loop
         exit when Pair_Counts.Is_Empty;

         declare
            Best    : constant Token_Pair := Find_Best;
            New_ID  : constant Token_ID   := T.Next_ID;
            New_Str : constant Unbounded_String :=
              T.Reverse_Vocab (Best.Left) & T.Reverse_Vocab (Best.Right);
         begin

            T.Vocab.Include (New_Str, New_ID);
            T.Reverse_Vocab.Include (New_ID, New_Str);
            T.Merges.Append (Best);
            T.Next_ID := T.Next_ID + 1;

            declare
               Best_Positions : constant Position_Vec.Vector :=
                 Positions (Best);
            begin
               Positions.Delete (Best);
               Pair_Counts.Delete (Best);

               for K in Best_Positions.First_Index ..
                        Best_Positions.Last_Index loop
                  declare
                     Pos    : constant Natural := Best_Positions (K);
                     L_Prev : constant Integer := Pool (Pos).Prev;
                     R_Pos  : constant Integer := Pool (Pos).Next;
                  begin
                     -- Skip dead nodes: a dead node's predecessor no
                     -- longer points back to it (its Prev is stale).
                     if (L_Prev < 0
                           or else Pool (Natural (L_Prev)).Next = Integer (Pos))
                        and then Pool (Pos).ID = Best.Left
                        and then R_Pos >= 0
                        and then Pool (Natural (R_Pos)).ID = Best.Right
                     then
                        declare
                           R_Next : constant Integer :=
                             Pool (Natural (R_Pos)).Next;
                        begin
                           if L_Prev >= 0 then
                              Remove_Position
                                ((Left  => Pool (Natural (L_Prev)).ID,
                                  Right => Best.Left));
                              Add_Position
                                ((Left  => Pool (Natural (L_Prev)).ID,
                                  Right => New_ID),
                                 Natural (L_Prev));
                           end if;

                           if R_Next >= 0 then
                              Remove_Position
                                ((Left  => Best.Right,
                                  Right => Pool (Natural (R_Next)).ID));
                              Add_Position
                                ((Left  => New_ID,
                                  Right => Pool (Natural (R_Next)).ID),
                                 Pos);
                           end if;

                           Pool (Pos).ID   := New_ID;
                           Pool (Pos).Next := R_Next;
                           if R_Next >= 0 then
                              Pool (Natural (R_Next)).Prev := Integer (Pos);
                           end if;
                        end;
                     end if;
                  end;
               end loop;
            end;
         end;
      end loop;

      -- Reconstruct IDs by walking the linked list
      IDs.Clear;
      declare
         I : Integer := 0;
      begin
         while I >= 0 loop
            IDs.Append (Pool (Natural (I)).ID);
            I := Pool (Natural (I)).Next;
         end loop;
      end;
   end Merge_BPE;

   function Train (Corpus_Path : String;
                   Vocab_Size  : Positive) return BPE_Tokenizer is
      T   : BPE_Tokenizer;
      IDs : ID_Vec.Vector;
   begin
      Initialize_Tokenizer (T);
      Read_And_Append_Corpus (Corpus_Path, IDs);
      Merge_BPE (T, IDs, Vocab_Size);
      return T;
   end Train;

   function Encode (T    : BPE_Tokenizer;
                    Text : String) return ID_Vec.Vector is
      IDs : ID_Vec.Vector;
   begin
      for Ch of Text loop
         IDs.Append (Token_ID (Character'Pos (Ch)));
      end loop;

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

   function Decode (T   : BPE_Tokenizer;
                    IDs : ID_Vec.Vector) return String is
      Result : Unbounded_String;
   begin
      for ID of IDs loop
         Result := Result & T.Reverse_Vocab (ID);
      end loop;
      return To_String (Result);
   end Decode;

   function Byte_To_Hex (B : Natural) return String is
      Hex_Chars : constant String := "0123456789abcdef";
   begin
      return (1 => Hex_Chars (B / 16 + 1),
              2 => Hex_Chars (B mod 16 + 1));
   end Byte_To_Hex;

   function Str_To_Hex (S : Unbounded_String) return String is
      Raw    : constant String := To_String (S);
      Result : Unbounded_String;
   begin
      for Ch of Raw loop
         Result := Result & Byte_To_Hex (Character'Pos (Ch));
      end loop;
      return To_String (Result);
   end Str_To_Hex;

   function Hex_Char_To_Val (Ch : Character) return Natural is
   begin
      case Ch is
         when '0' .. '9' => return Character'Pos (Ch) - Character'Pos ('0');
         when 'a' .. 'f' => return Character'Pos (Ch) - Character'Pos ('a') + 10;
         when others     =>
            raise Gusjo.Internal_Error with "Invalid hex character: " & Ch;
      end case;
   end Hex_Char_To_Val;

   function Hex_To_Str (Hex : String) return Unbounded_String is
      Result : Unbounded_String;
   begin
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

   procedure Save (T : BPE_Tokenizer; Path : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);

      Ada.Text_IO.Put_Line
        (File, "VOCAB " &
           Ada.Strings.Fixed.Trim
             (Natural'Image (Natural (T.Vocab.Length)), Ada.Strings.Both));

      for Cursor in T.Vocab.Iterate loop
         declare
            ID  : constant Token_ID         := Vocab_Map.Element (Cursor);
            Str : constant Unbounded_String := Vocab_Map.Key (Cursor);
         begin
            Ada.Text_IO.Put_Line
              (File,
               Ada.Strings.Fixed.Trim (Token_ID'Image (ID), Ada.Strings.Both)
               & "|" & Str_To_Hex (Str));
         end;
      end loop;

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

      declare
         Header     : constant String  := Ada.Text_IO.Get_Line (File);
         Vocab_Size : constant Natural := Parse_Header_Count (Header);
      begin
         for I in 1 .. Vocab_Size loop
            declare
               Line : constant String := Ada.Text_IO.Get_Line (File);
               Sep  : Natural         := 0;
            begin
               for J in Line'Range loop
                  if Line (J) = '|' then
                     Sep := J;
                     exit;
                  end if;
               end loop;

               declare
                  ID : constant Token_ID :=
                    Token_ID'Value (Ada.Strings.Fixed.Trim
                      (Line (Line'First .. Sep - 1), Ada.Strings.Both));
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
