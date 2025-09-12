with Gusjo;    use Gusjo;
with Gusjo.ds; use Gusjo.ds;

generic
   type Element_Type is private;
   with function "<"(Left, Right: in Element_Type) return Boolean is <>;

package Gusjo.Ds.Linked_List is
   
   type Linked_List_Type is private;
   
   procedure Insert(Item: in     Element_Type;
		    List: in out Linked_List_Type);
   
   function Get_Element_At_Index(List: in Linked_List_Type;
				 Index: in Integer) return Element_Type;
   
   function Size(List: in Linked_List_Type) return Integer;
   
   function Isempty(List: in Linked_List_Type) return Boolean;
   
private
   
   type List_Element_Type is
      record
	 Data: Element_Type;
	 Next: Linked_List_Type;
      end record;
   
   type Linked_List_Type is
     access List_Element_Type;
   
end Gusjo.Ds.Linked_List;
