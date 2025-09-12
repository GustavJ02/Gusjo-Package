generic
   type Element_Type is private;
   with function "<"(Left, Right: in Element_Type) return Boolean;
   with function "<="(Left, Right: in Element_Type) return Boolean;
   with function ">"(Left, Right: in Element_Type) return Boolean;
   with function ">="(Left, Right: in Element_Type) return Boolean;
package Gusjo.Ds.Heap is
   type Min_Heap_Type(Node_Max_Height : Positive) is private;
   type Max_Heap_Type(Node_Max_Height : Positive) is private;

   procedure Insert(Item: in Element_Type;
		    Heap: in out Min_Heap_Type);
   
   procedure Insert(Item: in Element_Type;
		    Heap: in out Max_Heap_Type);
   
   function Del_Min(Heap: in out Min_Heap_Type) return Element_Type;
   
   function Del_Max(Heap: in out Max_Heap_Type) return Element_Type;
   
   function Isempty(Heap: in Min_Heap_Type) return Boolean;
   
   function Isempty(Heap: in Max_Heap_Type) return Boolean;
   
private
   type Heap_Type is array(Natural range <>) of Element_Type;
   type Heap_Type_Ptr is access Heap_Type;

   type Min_Heap_Type(Node_Max_Height : Positive) is
      record
         Heap : Heap_Type_Ptr := new Heap_Type(0 .. 2**Node_Max_Height - 1);
         Size : Integer := 0;
      end record;

   type Max_Heap_Type(Node_Max_Height : Positive) is
      record
         Heap : Heap_Type_Ptr := new Heap_Type(0 .. 2**Node_Max_Height - 1);
         Size : Integer := 0;
      end record;
end Gusjo.Ds.Heap;

