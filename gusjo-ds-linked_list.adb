with Ada.Unchecked_Deallocation;

package body Gusjo.Ds.Linked_List is
   
   procedure Free is new Ada.Unchecked_Deallocation(List_Element_Type, Linked_List_Type);
   
   -- Linked List
   procedure Insert_First(Item: in     Element_Type;
			  List: in out Linked_List_Type) is
      Tmp : Linked_List_Type;
   begin
      Tmp:= new List_Element_Type;
      Tmp.Data:= Item;
      Tmp.Next:= List;
      List:= Tmp;
   end Insert_First;
   
   procedure Insert(Item: in     Element_Type;
		    List: in out Linked_List_Type) is
   begin
      if List = null or else Item < List.Data then
	 Insert_First(Item, List);
      else
	 Insert(Item, List.Next);
      end if;
   end Insert;
   
   function Get_Element_At_Index(List: in Linked_List_Type;
				 Index: in Integer) return Element_Type is
      Current_Node : Linked_List_Type := List;
   begin
      for I in 2..Index loop
	 if Isempty(Current_Node) then
	    raise Index_Out_Of_Bounds_Error with "Index " & Index'Image & " out of bounds";
	 end if;
	 Current_Node := Current_Node.Next;
      end loop;
      return Current_Node.Data;
   end Get_Element_At_Index;
   
   function Size(List: in Linked_List_Type) return Integer is
   begin
      if List = null then
	 return 0;
      else
	 return 1 + Size(List.Next);
      end if;
   end Size;
   
   function Isempty(List: in Linked_List_Type) return Boolean is
   begin
      return List = null;
   end Isempty;

         
end Gusjo.Ds.Linked_List;
