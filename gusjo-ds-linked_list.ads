with Gusjo; use Gusjo;

generic
   type Element_Type is private;

package Gusjo.Ds.Linked_List is
   
   type Linked_List_Type is private;
   
   procedure Insert(Item: in     Element_Type;
		    List: in out Linked_List_Type);
private
   
   type List_Element_Type is
      record
	 Data: Element_Type;
	 Next: Linked_List_Type;
      end record;
   
   type Linked_List_Type is
     access List_Element_Type;
   
end Gusjo.Ds.Linked_List;
