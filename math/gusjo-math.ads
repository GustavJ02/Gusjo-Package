package Gusjo.Math is
   
   type Matrix is private;
   
   type Row_Vector is private;
   
   type Column_Vector is private;
   
   type Float_Array is array (Natural range <>) of Float;
   
private
   
   type Matrix_Type is
     array(Natural range<>, Natural range<>) of Float;
   
   type Matrix is
     access Matrix_Type;
   
   type Row_Vector is
     access Matrix_Type;
   
   type Column_Vector is 
     access Matrix_Type;
   
end Gusjo.Math; 
