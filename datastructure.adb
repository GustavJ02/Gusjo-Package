with Ada.Integer_Text_Io; use Ada.Integer_Text_Io;
with Ada.Float_Text_Io;   use Ada.Float_Text_Io;
with Ada.Text_Io;         use Ada.Text_Io;

with Gusjo.Ds.Stack;
with Gusjo.Ds.Queue;

procedure Datastructure is
   package Integer_Stack is new Gusjo.Ds.Stack(Element_Type => Integer);
   use Integer_Stack;
   
   package Float_Queue is new Gusjo.Ds.Queue(Element_Type => Float);
   use Float_Queue;
   
   S: Stack_Type;
   I: Integer;
   Q: Queue_Type;
   F: Float;
begin
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
