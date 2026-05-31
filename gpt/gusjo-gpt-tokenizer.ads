with Ada.Containers.Vectors;
with Ada.Containers.Ordered_Maps;
with Ada.Strings.Unbounded;         use Ada.Strings.Unbounded;

package Gusjo.GPT.Tokenizer is

   type Token_ID is new Natural;

   type Token_Pair is record
      Left, Right : Token_ID;
   end record;

   function "<"(Left, Right : Token_Pair) return Boolean;

   package Vocab_Map is new Ada.Containers.Ordered_Maps
      (Key_Type   => Unbounded_String,
      Element_Type => Token_ID);

   package Reverse_Vocab_Map is new Ada.Containers.Ordered_Maps
      (Key_Type   => Token_ID,
      Element_Type => Unbounded_String);

   package Merge_Vec is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Token_Pair);

   package ID_Vec is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Token_ID);

   type BPE_Tokenizer is record
      Vocab        : Vocab_Map.Map;
      Reverse_Vocab : Reverse_Vocab_Map.Map;
      Merges       : Merge_Vec.Vector;
      Next_ID      : Token_ID := 256;
   end record;

   function Train
     (Corpus_Path : String;
      Vocab_Size  : Positive) return BPE_Tokenizer;

   -- Encode string → token IDs
   function Encode
     (T    : BPE_Tokenizer;
      Text : String) return ID_Vec.Vector;

   -- Decode token IDs → string
   function Decode
     (T   : BPE_Tokenizer;
      IDs : ID_Vec.Vector) return String;

   -- Save/load (for reuse across runs)
   procedure Save (T : BPE_Tokenizer; Path : String);
   function  Load (Path : String) return BPE_Tokenizer;


end Gusjo.GPT.Tokenizer;