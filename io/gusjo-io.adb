with Ada.Integer_Text_IO;        use Ada.Integer_Text_IO;
with Ada.Text_IO;                use Ada.Text_IO;
with Ada.Unchecked_Deallocation;

package body Gusjo.IO is

   procedure Append_Character(Head : in out My_String;
			      Tail : in out My_String;
			      Char : in Character) is
      New_Node : constant My_String :=
        new String_Entry'(Char => Char, Next => null);
   begin
      if Head = null then
	 Head := New_Node;
      else
	 Tail.Next := New_Node;
      end if;

      Tail := New_Node;
   end Append_Character;
   
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
   
   procedure Get_Line(File: in File_Type; Item: out My_String) is
      Tail : My_String := null;
      Char : Character;
   begin
      Item := null;

      while not End_Of_File(File) and then not End_Of_Line(File) loop
	 Get(File, Char);
	 Append_Character(Item, Tail, Char);
      end loop;

      if not End_Of_File(File) then
	 Skip_Line(File);
      end if;
   end Get_Line;
     
   procedure Get_Line(Item: out My_String) is
   begin
      Get_Line(Standard_Input, Item);
   end Get_Line;
   
   procedure Put(Item: in My_String) is
      Tmp : My_String := Item;
   begin
      while Tmp /= null loop
	 Put(Tmp.Char);
	 Tmp := Tmp.Next;
      end loop;
   end Put;
   
   procedure Put_Line(Item : in My_String) is
   begin
      Put(Item);
      New_Line;
   end Put_Line;
   
   function Count(Char: in Character;
		  Item: in My_String) return Integer is
      Tmp : My_String := Item;
      Result : Integer := 0;
   begin
      while Tmp /= null loop
	 if Tmp.Char = Char then
	    Result := Result + 1;
	 end if;

	 Tmp := Tmp.Next;
      end loop;

      return Result;
   end Count;
   
   procedure Free is new Ada.Unchecked_Deallocation(String_Entry, My_String);
   procedure Free_List is
     new Ada.Unchecked_Deallocation(My_String_List_Type, My_String_List);
   
   procedure Delete(Item : in out My_String) is
      Tmp : My_String;
   begin
      while Item /= null loop
	 Tmp := Item.Next;
	 Free(Item);
	 Item := Tmp;
      end loop;
   end Delete;

   procedure Delete(List : in out My_String_List) is
   begin
      if List /= null then
	 for I in List'Range loop
	    Delete(List(I));
	 end loop;

	 Free_List(List);
      end if;
   end Delete;
   
   function Split(Item: in My_String;
		  Char: in Character) return My_String_List is
      Result: My_String_List;
      Tmp : My_String := Item;
      Field_Index : Positive := 1;
      Field_Tail : My_String := null;
   begin
      Result := new My_String_List_Type(1 .. (Count(Char, Item) + 1));
      Result.all := (others => null);

      while Tmp /= null loop
	 if Tmp.Char = Char then
	    Field_Index := Field_Index + 1;
	    Field_Tail := null;
	 else
	    Append_Character(Result(Field_Index), Field_Tail, Tmp.Char);
	 end if;

	 Tmp := Tmp.Next;
      end loop;

      return Result;
   end Split;

   function Split_CSV(Item: in My_String;
		      Char: in Character) return My_String_List is
      function Field_Count return Positive is
	 Tmp : My_String := Item;
	 In_Quotes : Boolean := False;
	 Result : Positive := 1;
      begin
	 while Tmp /= null loop
	    if Tmp.Char = '"' then
	       if In_Quotes
		 and then Tmp.Next /= null
		 and then Tmp.Next.Char = '"'
	       then
		  Tmp := Tmp.Next;
	       else
		  In_Quotes := not In_Quotes;
	       end if;
	    elsif Tmp.Char = Char and then not In_Quotes then
	       Result := Result + 1;
	    end if;

	    Tmp := Tmp.Next;
	 end loop;

	 return Result;
      end Field_Count;

      Result : My_String_List := new My_String_List_Type(1 .. Field_Count);
      Tmp : My_String := Item;
      Field_Index : Positive := 1;
      Field_Tail : My_String := null;
      In_Quotes : Boolean := False;
   begin
      Result.all := (others => null);

      while Tmp /= null loop
	 if Tmp.Char = '"' then
	    if In_Quotes
	      and then Tmp.Next /= null
	      and then Tmp.Next.Char = '"'
	    then
	       Append_Character(Result(Field_Index), Field_Tail, '"');
	       Tmp := Tmp.Next;
	    else
	       In_Quotes := not In_Quotes;
	    end if;
	 elsif Tmp.Char = Char and then not In_Quotes then
	    Field_Index := Field_Index + 1;
	    Field_Tail := null;
	 else
	    Append_Character(Result(Field_Index), Field_Tail, Tmp.Char);
	 end if;

	 Tmp := Tmp.Next;
      end loop;

      return Result;
   end Split_CSV;
   
   procedure Put(Item: in My_String_List) is
   begin
      if Item = null then
	 Put("[]");
	 return;
      end if;

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
      Tmp : My_String := Item;
      Result : Integer := 0;
   begin
      while Tmp /= null loop
	 Result := Result + 1;
	 Tmp := Tmp.Next;
      end loop;

      return Result;
   end Length;

   function Is_Empty(Item : in My_String) return Boolean is
   begin
      return Item = null;
   end Is_Empty;
   
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
      Result : My_String := null;
      Tail : My_String := null;
   begin
      for I in Item'Range loop
	 Append_Character(Result, Tail, Item(I));
      end loop;
      
      return Result;
   end To_My_String;
   
end Gusjo.IO;
