with Ada.Unchecked_Deallocation;

package body Gusjo.Ds.Linked_List is
   
   procedure Free is new Ada.Unchecked_Deallocation(List_Element_Type, Linked_List_Type);
   
   -- Linked List
   procedure Insert(Item: in     Element_Type;
		    List: in out Linked_List_Type) is
      Tmp : Linked_List_Type;
   begin
      Tmp:= new List_Element_Type;
      Tmp.Data:= Item;
      List.Next:= List;
      List:= Tmp;
      Free(Tmp);
   end Insert;
         
end Gusjo.Ds.Linked_List;
