package Gusjo is
   
   Null_Pointer_Exception : exception;
   Internal_Error         : exception;
   
   funciton "*"(Left : in Float;
                Right: in Integer) return Integer;
   
   funciton "*"(Left : in Integer;
                Right: in Float) return Integer;

   funciton "*"(Left : in Float;
                Right: in Integer) return Float;
   
   funciton "*"(Left : in Integer;
                Right: in Float) return Float;
end Gusjo;
