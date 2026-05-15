with Gusjo;    use Gusjo;
with Gusjo.ds; use Gusjo.ds;

generic
   type Element_Type is private;

package Gusjo.Ds.Array_List is
   
   type Array_List_Type(Max_Size: positive) is private;
   
   procedure Insert(Item: in     Element_Type;
		              List: in out Array_List_Type);
   pragma Inline (Insert);

   procedure Insert_at_index(Item: in     Element_Type;
                            List: in out Array_List_Type;
                            Index: in Positive);
   pragma Inline (Insert_at_index);

   procedure Set_at_index(Item: in     Element_Type;
                          List: in out Array_List_Type;
                          Index: in Positive);
   pragma Inline (Set_at_index);

   procedure Set_preallocated_at_index(Item: in     Element_Type;
                                       List: in     Array_List_Type;
                                       Index: in Positive);
   pragma Inline (Set_preallocated_at_index);
   
   function Get_Element_At_Index(List: in Array_List_Type;
				                     Index: in Integer) return Element_Type;
   
   function Size(List: in Array_List_Type) return Integer;

   procedure Set_Size(List: in out Array_List_Type;
                      New_Size: in Natural);
   
   function Isempty(List: in Array_List_Type) return Boolean;

   procedure Delete(List: in out Array_List_Type);
   
private
   
    type Array_Type is
         array (Natural range <>) of Element_Type;

    type Array_Access is access all Array_Type;

    type Array_List_Type(Max_Size: positive) is
          record
             Data: Array_Access;
             Size: Integer := 0;
             Capacity: Positive := Max_Size;
          end record;
   
end Gusjo.Ds.Array_List;
