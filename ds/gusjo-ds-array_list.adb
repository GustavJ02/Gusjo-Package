with Ada.Unchecked_Deallocation;

package body Gusjo.Ds.Array_List is

   procedure Free is new Ada.Unchecked_Deallocation(Array_Type, Array_Access);

   procedure Increase_Size(List: in out Array_List_Type;
                           Least_Size: in Positive := 1) is
      Old_Data: Array_Access;
      New_Capacity : Positive := Positive'Max(List.Capacity * 1.5, Least_Size);
   begin
      Old_Data := List.Data;
      List.Data := New Array_Type(1 .. New_Capacity);
      for I in 1..List.Capacity loop
         List.Data(I) := Old_Data(I);
      end loop;
      Free(Old_Data);
      List.Capacity := New_Capacity;
   end Increase_Size;

   procedure Insert(Item: in     Element_Type;
          List: in out Array_List_Type) is
   begin
      if List.Data = null then
         List.Data := new Array_Type(1..List.Capacity);
      end if;
      if List.Size = List.Capacity then
         Increase_Size(List);
      end if;
      List.Data(List.Size + 1) := Item;
      List.Size := List.Size + 1;
   end Insert;

   procedure Insert_at_index(Item: in     Element_Type;
                            List: in out Array_List_Type;
                            Index: in Positive) is
   begin
      if List.Data = null then
         List.Data := new Array_Type(1..List.Capacity);
      end if;
      if Index > List.Capacity then
         Increase_Size(List, Index);
      end if;
      List.Data(Index) := Item;
      List.Size := List.Size + 1;
   end Insert_at_index;
   
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

   procedure Delete(List: in out Array_List_Type) is
   begin
      if List.Data /= null then
         Free(List.Data);
         List.Data := null;
         List.Size := 0;
      end if;
   end Delete;

end Gusjo.Ds.Array_List;