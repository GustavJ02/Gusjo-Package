with Ada.Unchecked_Deallocation;

package body Gusjo.Ds.Queue is
   
   procedure Free is new Ada.Unchecked_Deallocation(Queue_Element_Type, Queue_Ptr_Type);
   
   -- Queue
   procedure Enqueue(Item:  in     Element_Type;
		     Queue: in out Queue_Type) is
   begin
      if Queue.Back = null then
	 Queue.Front:= new Queue_Element_Type'(Data => Item, Next => null);
	 Queue.Back:= Queue.Front;
      else
	 Queue.Back.Next:= new Queue_Element_Type'(Data => Item, Next => null);
	 Queue.Back:= Queue.Back.Next;
	 
	 Queue.Size:= Queue.Size + 1;
      end if;
   end Enqueue;
   
   procedure Dequeue(Item:     out Element_Type;
		     Queue: in out Queue_Type) is
      Tmp: Queue_Ptr_Type;
   begin
      if Queue.Front = null then
	 raise Null_Pointer_Exception with "Queue is empty";
      else
	 Item:= Queue.Front.Data;
	 Tmp:= Queue.Front.Next;
	 Free(Queue.Front);
	 Queue.Front:= Tmp;
	 
	 Queue.Size:= Queue.Size - 1;
      end if;
   end Dequeue;
   
   function Isempty(Queue: in Queue_Type) return Boolean is
   begin
      return Queue.Front = null;
   end Isempty;
   
   function Front(Queue: in Queue_Type) return Element_Type is
   begin
      if Queue.Front = null then
	 raise Null_Pointer_Exception with "Queue is empty";
      else
	 return Queue.Front.Data;
      end if;
   end Front;
   
   function Back(Queue: in Queue_Type) return Element_Type is
   begin
      if Queue.Back = null then
	 raise Null_Pointer_Exception with "Queue is empty";
      else
	 return Queue.Back.Data;
      end if;
   end Back;
   
   function Size(Queue: in Queue_Ptr_Type) return Integer is
   begin
      if Queue = null then
	 return 0;
      else
	 return 1 + Size(Queue.Next);
      end if;
   end Size;
   
   function Size(Queue: in Queue_Type) return Integer is
   begin
      return Queue.Size;
   end Size;

end Gusjo.Ds.Queue;
