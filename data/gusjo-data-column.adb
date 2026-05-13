package body Gusjo.Data.Column is

   procedure Append(Col : in out Column_Type; Item : in Element_Type) is
   begin
      Column_Storage.Insert(Item, Col.Data);
   end Append;

   function Get(Col : in Column_Type; Row : in Positive) return Element_Type is
   begin
      return Column_Storage.Get_Element_At_Index(Col.Data, Row);
   end Get;

   function Row_Count(Col : in Column_Type) return Natural is
   begin
      return Column_Storage.Size(Col.Data);
   end Row_Count;

   function Is_Empty(Col : in Column_Type) return Boolean is
   begin
      return Column_Storage.Isempty(Col.Data);
   end Is_Empty;

   procedure Delete(Col : in out Column_Type) is
   begin
      Column_Storage.Delete(Col.Data);
   end Delete;

end Gusjo.Data.Column;
