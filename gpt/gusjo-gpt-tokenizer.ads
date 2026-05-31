with Ada.Containers.Vectors;
with Ada.Containers.Hashed_Maps;    -- replaces Ordered_Maps
with Ada.Strings.Unbounded;         use Ada.Strings.Unbounded;
with Ada.Strings.Unbounded.Hash;    -- free hash for Unbounded_String
with Ada.Containers;                use type Ada.Containers.Hash_Type;

package Gusjo.GPT.Tokenizer is

   type Token_ID is new Natural;

   type Token_Pair is record
      Left, Right : Token_ID;
   end record;

   -- Hash for Token_ID: just cast it, IDs are already well-distributed integers
   function Hash_Token_ID (ID : Token_ID) return Ada.Containers.Hash_Type is
     (Ada.Containers.Hash_Type (ID));

   -- Equality for Token_ID (required by Hashed_Maps)
   function Token_ID_Equal (A, B : Token_ID) return Boolean is
     (A = B);

   package Vocab_Map is new Ada.Containers.Hashed_Maps
     (Key_Type        => Unbounded_String,
      Element_Type    => Token_ID,
      Hash            => Ada.Strings.Unbounded.Hash,
      Equivalent_Keys => "=");

   package Reverse_Vocab_Map is new Ada.Containers.Hashed_Maps
     (Key_Type        => Token_ID,
      Element_Type    => Unbounded_String,
      Hash            => Hash_Token_ID,
      Equivalent_Keys => Token_ID_Equal);

   package Merge_Vec is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Token_Pair);

   package ID_Vec is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Token_ID);

   type BPE_Tokenizer is record
      Vocab         : Vocab_Map.Map;
      Reverse_Vocab : Reverse_Vocab_Map.Map;
      Merges        : Merge_Vec.Vector;
      Next_ID       : Token_ID := 256;
   end record;

   procedure Initialize_Tokenizer (T : in out BPE_Tokenizer);

   procedure Read_And_Append_Corpus (Corpus_Path : in String;
                                     IDs         : in out ID_Vec.Vector);

   procedure Merge_BPE (T          : in out BPE_Tokenizer;
                        IDs        : in out ID_Vec.Vector;
                        Vocab_Size : in Positive);

   function Train
     (Corpus_Path : String;
      Vocab_Size  : Positive) return BPE_Tokenizer;

   function Encode
     (T    : BPE_Tokenizer;
      Text : String) return ID_Vec.Vector;

   function Decode
     (T   : BPE_Tokenizer;
      IDs : ID_Vec.Vector) return String;

   function Decode (T  : BPE_Tokenizer;
                    ID : Token_ID) return String;

   procedure Save (T : BPE_Tokenizer; Path : String);
   function  Load (Path : String) return BPE_Tokenizer;

end Gusjo.GPT.Tokenizer;