with Gusjo;    use Gusjo;
with Gusjo.ds; use Gusjo.ds;

generic
   type Element_Type is private;

package Gusjo.Ds.Array_List is
   
   type Array_List_Type(Max_Size: positive) is private;

   type Arrat_List_Type is private;
   
   procedure Insert(Item: in     Element_Type;
		              List: in out Array_List_Type);
   
   function Get_Element_At_Index(List: in Array_List_Type;
				                     Index: in Integer) return Element_Type;
   
   function Size(List: in Array_List_Type) return Integer;
   
   function Isempty(List: in Array_List_Type) return Boolean;
   
private
   
   type Array_Type is
      Array(Natural range <>) of Element_Type;
   
   type Array_List_Type is
     record
      Data: access Array_Type;
      Size: Integer := 0;
      Max_Size: Integer := 8;
     end record;

   type Array_List_Type(Max_Size: positive) is
     record
      Data: access Array_Type;
      Size: Integer := 0;
      Max_Size: Integer := Max_Size;
     end record;
   
end Gusjo.Ds.Array_List;
