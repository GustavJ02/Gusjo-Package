package body Gusjo.Math.Optimization is
   
   function Linear_Model(Mode : in Mode_Type) return Model is
      Result: Model;
   begin
      Result.Mode := Mode;
      return Result;
   end Linear_Model;
   
   function Create_Variable(Name : in My_String;
		                      Restriction : in Sign_Restriction := Free) return Variable is
      Result : Variable;
   begin
      Result.Value       := 0.0;
      Result.Name        := Name;
      Result.Restriction := Restriction;
      return result;
   end Create_Variable;
   
   function Create_Variable(Name : in String;
		                      Restriction : in Sign_Restriction := Free) return Variable is
   begin
      return Create_Variable(To_My_String(Name), Restriction);
   end Create_Variable;
   
   procedure Update_Variables(Variables : in out Variable_List_Ptr_Type;
			                     New_Variable  : in Variable) is
      Tmp : Variable_List_Type(1..Variables'Last) := Variables;
   begin
      Variables := new Variable_List_Type(1..(Variables'Last + 1));
      
      for I in Tmp'Range loop
	 Variables(I) := Tmp(I);
      end loop;
      
      Variables(Variables'Last) := Variable;
   end Update_Variables;

   procedure Add_Variable(Model : in out Model;
			 Variable : in Variable) is
   begin
      if Model.Variables = null then
	 Model.Variables := new Variable_List_Type(1..1);
	 Model.Variables(1) := Variable;
      else
	 Update_Variables(Model.Variables, Variable);
      end if;
      
   end Add_Variable;
   
end Gusjo.Math.Optimization;
