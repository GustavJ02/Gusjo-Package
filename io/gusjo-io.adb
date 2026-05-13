with Ada.Integer_Text_IO;        use Ada.Integer_Text_IO;
with Ada.Text_IO;                use Ada.Text_IO;
with Ada.Unchecked_Deallocation;

package body Gusjo.IO is
   
   procedure Put_Padding(Item: in Natural;
			 Width: in Integer) is
      
      String_Value: String(1..Width) := (others => '0');
      Item_String: String(Integer'Image(Item)'range) := Item'Image;
      
   begin
      
      for I in reverse Item_String'Range loop
	 if Item_String(I) in '0'..'9' then
	    String_Value(String_Value'Last - Item_String'Last + I) := Item_String(I);
	 end if;
      end loop;
      Put(String_Value);
   end Put_Padding;
   
   
   procedure Get_Correct(Item: out Character) is
   begin
      loop
	 Get(Item);
	 exit when Item /= ' ';
      end loop;
   end Get_Correct;
   
   procedure Fill_String(File: in File_Type; Item: in out My_String) is
   begin
      if not End_Of_Line then
	 Item := new String_Entry;
	 Get(File, Item.Char);
	 Fill_String(File, Item.Next);
      end if;
   end Fill_String;
   
   procedure Fill_String_First(File: in File_Type; Item: in out My_String) is
   begin
      if Item = null then
	 raise Null_Pointer_Exception;
      else
	 Get_Correct(File, Item.Char);
	 Fill_String(File, Item.Next);
      end if;
   end Fill_String_First;

   procedure Get_Line(File: in File_Type; Item: out My_String) is
   begin
      Item:= new String_Entry;
      Fill_String_First(File, Item);
      Skip_Line(File);
   end Get_Line;
     
   procedure Get_Line(Item: out My_String) is
   begin
      Get_Line(Standard_Input, Item);
   end Get_Line;
   
   procedure Put(Item: in My_String) is
   begin
      Put(Item.Char);
      if Item.Next /= null then
	 Put(Item.Next);
      end if;
   end Put;
   
   procedure Put_Line(Item : in My_String) is
   begin
      Put(Item);
      New_Line;
   end Put_Line;
   
   function Count(Char: in Character;
		  Item: in My_String) return Integer is
   begin
      if Item.Next /= null and Item.Char = Char then
	 if Item.Next.Char = Char then
	    return Count(Char, Item.Next);
	 else
	    return Count(Char, Item.Next) + 1;
	 end if;
      elsif Item.Next /= null then
	 return Count(Char, Item.Next);
      else
	 return 0;
      end if;
   end Count;
   
   procedure Free is new Ada.Unchecked_Deallocation(String_Entry, My_String);
   
   procedure Delete(Item : in out My_String) is
   begin
      Free(Item);
   end Delete;

   procedure Delete(List : in out My_String_List) is
   begin
      for I in List'Range loop
         Delete(List(I));
      end loop;
      Free(List);
   end Delete;
   
   procedure Split_On_First(Char: in Character;
			    First: in out My_String;
			    Remaining: in out My_String) is
   begin
      if First.Char = Char then
	 Remaining := First.Next;
	 Free(First);
	 First := null;
      elsif First.Next /= null then
	Split_On_First(Char, First.Next, Remaining);
      end if;
   end Split_On_First;
   
   procedure Clear_Init_Char(Char: in Character;
			     Item: in out My_String) is
      Tmp: My_String;
   begin
      if Item.Char = Char then
	 Tmp:= Item.Next;
	 Free(Item);
	 Item := Tmp;
	 if Item.Next /= null then
	    Clear_Init_Char(Char, Item);
	 end if;
      end if;
   end Clear_Init_Char;
   
   procedure Split_First(Char: in Character;
			 Remaining: in out My_String;
			 First: out My_String) is
   begin
      First := Remaining;
      Split_On_First(Char, First, Remaining);
      Clear_Init_Char(Char, Remaining);
   end Split_First;
   
   function Split(Item: in My_String;
		  Char: in Character) return My_String_List is
      
      Nr_Of_Char: Integer;
      Result: My_String_List;
      
      First_String: My_String;
      Remaining_String: My_String := Item;
      
   begin
            
      Nr_Of_Char := Count(Char, Remaining_String);
      Result := new My_String_List_Type(1 .. (Nr_Of_Char + 1));
      
      for I in Result'Range loop
	 Split_First(Char, Remaining_String, First_String);
	 Result(I) := First_String;
      end loop;
      
      return Result;
   end Split;
   
   procedure Put(Item: in My_String_List) is
   begin
      Put('[');
      for I in Item'Range loop
	 Put(Item(I));
	 if I /= Item'Last then
	    Put(',');
	 end if;
      end loop;
      Put(']');
   end Put;
   
   function Length(Item : in My_String) return Integer is
   begin
      if Item = null then
	 return 0;
      else
	 return 1 + Length(Item);
      end if;
   end Length;
   
   function To_String(Item : in My_String;
		      Len  : in Integer) return String is
      Result : String(1..Len);
      Tmp : My_String := Item;
   begin
      
      for I in Result'Range loop
	 Result(I) := Tmp.Char;
	 Tmp := Tmp.Next;
      end loop;
      
      return Result;
   end To_String;
   
   function To_String(Item : in My_String) return String is
   begin
      return To_String(Item, Length(Item));
   end To_String;
   
   function To_My_String(Item : in String) return My_String is
      Result, Tmp : My_String := null;
   begin
      Result := new String_Entry;
      
      for I in reverse Item'Range loop
	 Result := new String_Entry;
	 
	 Result.Char := Item(I);
	 Result.Next := Tmp;
	 
	 Tmp := Result;
	 
      end loop;
      
      return Result;
   end To_My_String;
   
end Gusjo.IO;
