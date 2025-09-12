with Ada.Integer_Text_Io; use Ada.Integer_Text_Io;
with Ada.Float_Text_Io;   use Ada.Float_Text_Io;
with Ada.Text_Io;         use Ada.Text_Io;

with Gusjo.Ds;            use Gusjo.Ds;

with Ada.Numerics.Discrete_Random;

with Gusjo.Ds.Linked_List;
with Gusjo.Ds.Stack;
with Gusjo.Ds.Queue;
with Gusjo.Ds.Heap;

procedure Datastructure is
   package Integer_Stack is new Gusjo.Ds.Stack(Element_Type => Integer);
   use Integer_Stack;
   
   package Float_Queue is new Gusjo.Ds.Queue(Element_Type => Float);
   use Float_Queue;
   
   package Integer_Linked_List is new Gusjo.Ds.Linked_List(Element_Type => Integer, "<" => "<");
   use Integer_Linked_List;

   package Integer_Heap is new Gusjo.Ds.Heap(Element_Type => Integer, "<" => "<", ">" => ">", "<=" => "<=", ">=" => ">=");
   use Integer_Heap;
   
   subtype Positive_Subrange is Integer range 1 .. 500;
   
   package Positive_Random is new Ada.Numerics.Discrete_Random(Positive_Subrange);
   use Positive_Random;

   S: Stack_Type;
   I: Integer;
   Q: Queue_Type;
   F: Float;
   Ll : Linked_List_Type;
   Heap : Min_Heap_Type(8);
   
   G : Generator;
   
   
begin
   
   Put("Version: " & Ada'Version);
   
   New_Line(2);
   
   Reset(G);
   
   loop
      begin
	 Insert(Random(G), Heap);
      exception
	 when Heap_Overflow =>
	    exit;
      end;
   end loop;
   
   while not Isempty(Heap) loop
      Put(' ');
      Put(Del_Min(Heap), Width => 0);
   end loop;
   New_Line;
   
   for I in reverse  11..20 loop
      Insert(I, Ll);
   end loop;
   
   for I in 1..Size(Ll) loop
      Put("Index" & I'Image & ": ");
      Put(Get_Element_At_Index(Ll, I), Width => 0);
      New_Line;
   end loop;
   New_Line;
     
   for I in 1..10 loop
      Push(I, S);
   end loop;
   
   while not Isempty(S) loop
      Pop(I, S);
      Put(I, Width => 0);
      New_Line;
   end loop;
   
   for I in 1..10 loop
      Enqueue(Float(I), Q);
   end loop;
   
   while not Isempty(Q) loop
      Dequeue(F, Q);
      Put(F, Fore => 0, Aft => 1, Exp => 0);
      if not Isempty(Q) then
	 Put(" - ");
      end if;
   end loop;
   
end Datastructure;
