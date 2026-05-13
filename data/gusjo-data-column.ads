--  Generic column type for typed, homogeneous data storage
with Gusjo.Ds.Array_List;

generic
   type Element_Type is private;

package Gusjo.Data.Column is

   package Column_Storage is new Gusjo.Ds.Array_List(Element_Type => Element_Type);

   type Column_Type(Max_Size : Positive) is record
      Data : Column_Storage.Array_List_Type(Max_Size);
   end record;

   --  Append an element to the column
   procedure Append(Col : in out Column_Type; Item : in Element_Type);

   --  Get element at row index (1-based)
   function Get(Col : in Column_Type; Row : in Positive) return Element_Type;

   --  Number of rows in column
   function Row_Count(Col : in Column_Type) return Natural;

   --  Check if column is empty
   function Is_Empty(Col : in Column_Type) return Boolean;

   procedure Delete(Col : in out Column_Type);

end Gusjo.Data.Column;