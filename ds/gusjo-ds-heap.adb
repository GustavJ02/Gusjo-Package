with Gusjo;    use Gusjo;
with Gusjo.Ds; use Gusjo.Ds;

package body Gusjo.Ds.Heap is

   procedure Swap(Heap: in out Heap_Type; Index1, Index2: in Integer) is
      Temp : Element_Type := Heap(Index1);
   begin
      Heap(Index1) := Heap(Index2);
      Heap(Index2) := Temp;
   end Swap;

   procedure Sink_Min(Heap: in out Min_Heap_Type; Start: in Integer) is
      Current : Integer := Start;
      Child   : Integer;
   begin
      loop
         Child := 2 * Current + 1;

         if Child < Heap.Size - 1 and then Heap.Heap(Child + 1) < Heap.Heap(Child) then
            Child := Child + 1;
         end if;

         exit when Child >= Heap.Size or else Heap.Heap(Current) <= Heap.Heap(Child);

         Swap(Heap.Heap.all, Current, Child);
         Current := Child;
      end loop;
   end Sink_Min;

   procedure Sink_Max(Heap: in out Max_Heap_Type; Start: in Integer) is
      Current : Integer := Start;
      Child   : Integer;
   begin
      loop
         Child := 2 * Current + 1; -- Left child index

         if Child < Heap.Size - 1 and then Heap.Heap(Child + 1) > Heap.Heap(Child) then
            Child := Child + 1;
         end if;

         exit when Child >= Heap.Size or else Heap.Heap(Current) >= Heap.Heap(Child);

         Swap(Heap.Heap.all, Current, Child);
         Current := Child;
      end loop;
   end Sink_Max;

   procedure Swim_Min(Heap: in out Min_Heap_Type; Start: in Integer) is
      Current : Integer := Start;
      Parent  : Integer;
   begin
      while Current > 0 loop
         Parent := (Current - 1) / 2; -- Parent index

         exit when Heap.Heap(Current) >= Heap.Heap(Parent);

         Swap(Heap.Heap.all, Current, Parent);
         Current := Parent;
      end loop;
   end Swim_Min;

   procedure Swim_Max(Heap: in out Max_Heap_Type; Start: in Integer) is
      Current : Integer := Start;
      Parent  : Integer;
   begin
      while Current > 0 loop
         Parent := (Current - 1) / 2; -- Parent index

         exit when Heap.Heap(Current) <= Heap.Heap(Parent);

         Swap(Heap.Heap.all, Current, Parent);
         Current := Parent;
      end loop;
   end Swim_Max;

   procedure Insert(Item: in Element_Type; Heap: in out Min_Heap_Type) is
   begin
      if Heap.Size = Heap.Heap'Last then
         raise Heap_Overflow with "Max capacity reached.";
      end if;

      Heap.Heap(Heap.Size) := Item;
      Swim_Min(Heap, Heap.Size);
      Heap.Size := Heap.Size + 1;
   end Insert;

   procedure Insert(Item: in Element_Type; Heap: in out Max_Heap_Type) is
   begin
      if Heap.Size = Heap.Heap'Last then
         raise Heap_Overflow with "Max capacity reached.";
      end if;

      Heap.Heap(Heap.Size) := Item;
      Swim_Max(Heap, Heap.Size);
      Heap.Size := Heap.Size + 1;
   end Insert;

   function Del_Min(Heap: in out Min_Heap_Type) return Element_Type is
      Result : Element_Type := Heap.Heap(0);
   begin
      if Heap.Size = 0 then
         raise Heap_Underflow with "Cannot delete from an empty Min_Heap_Type.";
      end if;

      Heap.Heap(0) := Heap.Heap(Heap.Size - 1);
      Heap.Size := Heap.Size - 1;
      Sink_Min(Heap, 0);

      return Result;
   end Del_Min;

   function Del_Max(Heap: in out Max_Heap_Type) return Element_Type is
      Result : Element_Type := Heap.Heap(0);
   begin
      if Heap.Size = 0 then
         raise Heap_Underflow with "Cannot delete from an empty Max_Heap_Type.";
      end if;

      Heap.Heap(0) := Heap.Heap(Heap.Size - 1);
      Heap.Size := Heap.Size - 1;
      Sink_Max(Heap, 0);

      return Result;
   end Del_Max;
   
   function Isempty(Heap: in Min_Heap_Type) return Boolean is
   begin
      return Heap.Size = 0;
   end Isempty;
   
   function Isempty(Heap: in Max_Heap_Type) return Boolean is
   begin
      return Heap.Size = 0;
   end Isempty;

end Gusjo.Ds.Heap;
