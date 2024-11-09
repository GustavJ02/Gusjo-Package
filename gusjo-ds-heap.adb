with Gusjo;    use Gusjo;
with Gusjo.Ds; use Gusjo.Ds;

package body Gusjo.Ds.Heap is
   
   procedure Insert(Item: in Element_Type;
		    Heap: in out Min_Heap_Type) is
      Position : Heap_Index := Heap.Size;
   begin
      if Heap.Size = Heap.Heap'Last then
         raise Heap_Overflow with "Max capacity reached.";
      end if;

      -- Place the item at the end of the heap
      Heap.Heap(Position) := Item;
      Heap.Size := Heap.Size + 1;

      -- Bubble up the item to maintain min-heap property
      while Position > 0 loop
         declare
            Parent : constant Heap_Index := (Position - 1) / 2;
         begin
            if Heap.Heap(Parent) <= Heap.Heap(Position) then
	       exit; -- Heap property is satisfied
            end if;

            -- Swap with parent
            declare
	       Temp : Element_Type := Heap.Heap(Parent);
            begin
	       Heap.Heap(Parent) := Heap.Heap(Position);
	       Heap.Heap(Position) := Temp;
            end;

            -- Move to parent's position
            Position := Parent;
         end;
      end loop;
   end Insert;

   procedure Insert(Item: in Element_Type;
		    Heap: in out Max_Heap_Type) is
      Position : Heap_Index := Heap.Size;
   begin
      if Heap.Size = Heap.Heap'Last then
         raise Program_Error with "Heap overflow: Max capacity reached.";
      end if;

      -- Place the item at the end of the heap
      Heap.Heap(Position) := Item;
      Heap.Size := Heap.Size + 1;

      -- Bubble up the item to maintain max-heap property
      while Position > 0 loop
         declare
            Parent : constant Heap_Index := (Position - 1) / 2;
         begin
            if Heap.Heap(Parent) >= Heap.Heap(Position) then
	       exit; -- Heap property is satisfied
            end if;

            -- Swap with parent
            declare
	       Temp : Element_Type := Heap.Heap(Parent);
            begin
	       Heap.Heap(Parent) := Heap.Heap(Position);
	       Heap.Heap(Position) := Temp;
            end;

            -- Move to parent's position
            Position := Parent;
            end;
	 end loop;
      end Insert;
   
   function Del_Min(Heap: in out Min_Heap_Type) return Element_Type;
   
   function Del_Max(Heap: in out Max_Heap_Type) return Element_Type;
   
end Gusjo.Ds.Heap;
