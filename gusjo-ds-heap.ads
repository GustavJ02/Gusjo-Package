generic
   type Element_Type is private;
function "<"(Left, Right: in Element_Type) return Boolean;
package Gusjo.Ds.Heap is
   type Min_Heap_Type(Node_Max_Height : Positive) is private;
   type Max_Heap_Type(Node_Max_Height : Positive) is private;

   procedure Insert(Item: in Element_Type;
		    Heap: in out Min_Heap_Type);
   
   procedure Insert(Item: in Element_Type;
		    Heap: in out Max_Heap_Type);
   
   function Del_Min(Heap: in out Min_Heap_Type) return Element_Type;
   
   function Del_Max(Heap: in out Max_Heap_Type) return Element_Type;
   
private
   type Heap_Index is range 0 .. Integer(2**(Node_Max_Height + 1) - 2);
   
   type Heap_Type is array(Heap_Index) of Element_Type;
   
   type Min_Heap_Type is
      record
	 Heap: Heap_Type;
	 Size: Integer := 0;
      end record;
   
   type Max_Heap_Type is
      record
	 Heap: Heap_Type;
	 Size: Integer := 0;
      end record;
end Gusjo.Ds.Heap;

