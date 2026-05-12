with Ada.Unchecked_Deallocation;

package body Gusjo.Ds.Array_List is

   procedure Free is new Ada.Unchecked_Deallocation(Array_Type, Array_Access);

   procedure Insert(Item: in     Element_Type;
          List: in out Array_List_Type) is
   begin
      if List.Size = List.Capacity then
         declare
            Old_Data : Array_Access;
         begin
            Old_Data := List.Data;
            List.Data := new Array_Type(1..List.Capacity * 2);
            for I in 1..List.Capacity loop
               List.Data(I) := Old_Data(I);
            end loop;
            Free(Old_Data);
            List.Capacity := List.Capacity * 2;
         end;
      end if;
      if List.Data = null then
         List.Data := new Array_Type(1..List.Capacity);
      end if;
      List.Data(List.Size + 1) := Item;
      List.Size := List.Size + 1;
   end Insert;
   
   function Get_Element_At_Index(List: in Array_List_Type;
             Index: in Integer) return Element_Type is
   begin
      if Index < 1 or else Index > List.Size then
    raise Index_Out_Of_Bounds_Error with "Index " & Index'Image & " out of bounds";
      end if;
      return List.Data(Index);
   end Get_Element_At_Index;
   
   function Size(List: in Array_List_Type) return Integer is
   begin
      return List.Size;
   end Size;
   
   function Isempty(List: in Array_List_Type) return Boolean is
   begin
      return List.Size = 0;
   end Isempty;

end Gusjo.Ds.Array_List;