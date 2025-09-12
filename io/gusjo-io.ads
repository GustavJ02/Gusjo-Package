with Gusjo;  use Gusjo;

package Gusjo.IO is
   
   type My_String is private;
   
   type My_String_List_Type is
     array(Positive range <>) of My_String;
   
   type My_String_List is
     access My_String_List_Type;
   
   procedure Get_Line(Item: out My_String);
   
   procedure Put(Item: in My_String);
   
   procedure Put_Line(Item : in My_String);
     
   function Split(Item: in My_String;
		  Char: in Character) return My_String_List;
   
   procedure Put(Item: in My_String_List);
   
   procedure Put_Padding(Item: in Natural;
			 Width: in Integer);
   
   procedure Get_Correct(Item: out Character);
   
   procedure Delete(Item : in out My_String);
   
   function Length(Item : in My_String) return Integer;
   
   function To_String(Item : in My_String) return String;
   
   function To_My_String(Item : in String) return My_String;
   
private
   
   type String_Entry;
   
   type My_String is
     access String_Entry;
   
   type String_Entry is
      record
	 Char: Character;
	 Next: My_String;
      end record;
end Gusjo.IO;
