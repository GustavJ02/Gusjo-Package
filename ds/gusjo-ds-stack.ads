with Gusjo; use Gusjo;

generic
   type Element_Type is private;

package Gusjo.Ds.Stack is
   
   type Stack_Type is private;

   procedure Push(Item:  in     Element_Type;
		  Stack: in out Stack_Type);
   
   procedure Pop(Item:     out Element_Type;
		 Stack: in out Stack_Type);
   
   function Isempty(Stack: in Stack_Type) return Boolean;
   
   function Top(Stack: in Stack_Type) return Element_Type;

   function Size(Stack: in Stack_Type) return Integer;

private
   
   type Stack_Element_Type is
      record
	 Data: Element_Type;
	 Next: Stack_Type;
      end record;
   
   type Stack_Type is
     access Stack_Element_Type;

   
end Gusjo.Ds.Stack;
