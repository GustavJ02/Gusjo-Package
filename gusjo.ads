package Gusjo is
   
   Null_Pointer_Exception : exception;
   Internal_Error         : exception;
   
   -- * Operators
   function "*"(Left : in Float;
                Right: in Integer) return Integer;
   
   function "*"(Left : in Integer;
                Right: in Float) return Integer;

   function "*"(Left : in Float;
                Right: in Integer) return Float;
   
   function "*"(Left : in Integer;
                Right: in Float) return Float;	
   -- + Operators
   function "+"(Left : in Integer;	
	        Right: in Float) return Integer;	
		       
   function "+"(Left : in Float;	
	        Right: in Integer) return Integer;
		       
   function "+"(Left : in Integer;	
	        Right: in Float) return Float;	
		       
   function "+"(Left : in Float;	
	        Right: in Integer) return Float;	
   -- - Operators       
   function "-"(Left : in Integer;	
	        Right: in Float) return Integer;	
		       
   function "-"(Left : in Float;	
	        Right: in Integer) return Integer;	
		       
   function "-"(Left : in Integer;	
	        Right: in Float) return Float;	
		       
   function "-"(Left : in Float;	
	        Right: in Integer) return Float;	
		       
   -- Comparators      
   function ">"(Left : in Float;	
                Right: in Integer) return Boolean;	
		       
   function ">"(Left : in Integer;	
                Right: in Float) return Boolean;	
		       
   function ">="(Left : in Float;	
                 Right: in Integer) return Boolean;	
		       
   function ">="(Left : in Integer;	
                 Right: in Float) return Boolean;	
		       
   function "<"(Left : in Float;	
                Right: in Integer) return Boolean;	
		       
   function "<"(Left : in Integer;	
                Right: in Float) return Boolean;
		       
   function "<="(Left : in Float;	
                 Right: in Integer) return Boolean;
		       
   function "<="(Left : in Integer;	
                 Right: in Float) return Boolean;
		       
   function "="(Left : in Float;	
                Right: in Integer) return Boolean;
		       
   function "="(Left : in Integer;	
                Right: in Float) return Boolean;
end Gusjo;
