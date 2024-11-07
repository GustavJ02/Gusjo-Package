package body Gusjo is
   -- * Operators
   function "*"(Left : in Float;
                Right: in Integer) return Integer is	
		begin  
		return Integer(Left) * Right;	
		end "*";
   
   function "*"(Left : in Integer;
                Right: in Float) return Integer is	
		begin  
		return Right * Left;	
		end "*";

   function "*"(Left : in Float;
                Right: in Integer) return Float is	
		begin  
		return Left * Float(Right);	
		end "*";
   
   function "*"(Left : in Integer;
                Right: in Float) return Float is	
		begin  
		return Right * Left;	
		end "*";     
		
   -- + Operators
   function "+"(Left : in Integer;	
	        Right: in Float) return Integer is	
		begin  
		return Left + Integer(Right);	
		end "+";
		       
   function "+"(Left : in Float;	
	        Right: in Integer) return Integer is	
		begin  
		return Right + Left;	
		end "+";
		       
   function "+"(Left : in Integer;	
	        Right: in Float) return Float is	
		begin  
		return Float(Left) + Right;	
		end "+";
		       
   function "+"(Left : in Float;	
	        Right: in Integer) return Float is	
		begin  
		return Right + Left;	
		end "+";
   -- - Operators       
   function "-"(Left : in Integer;	
	        Right: in Float) return Integer is	
		begin  
		return Left - Integer(Right);	
		end "-";
		       
   function "-"(Left : in Float;	
	        Right: in Integer) return Integer is	
		begin  
		return Integer(Left) - Right;	
		end "-";
		       
   function "-"(Left : in Integer;	
	        Right: in Float) return Float is
		begin  
		return Float(Left) - Right;	
		end "-";
		       
   function "-"(Left : in Float;	
	        Right: in Integer) return Float is	
		begin  
		return Left - Float(Right);	
		end "-";    
		
      -- Comparators      
   function ">"(Left : in Float;	
                Right: in Integer) return Boolean is	
		begin  
		return Left > Float(Right);	
		end ">";	
		       
   function ">"(Left : in Integer;	
                Right: in Float) return Boolean is	
		begin  
		return Float(Left) > Right;	
		end ">";	   
		    
   function ">="(Left : in Float;	
                Right: in Integer) return Boolean is	
		begin  
		return Left >= Float(Right);	
		end ">=";	
		       
   function ">="(Left : in Integer;	
                Right: in Float) return Boolean is	
		begin  
		return Float(Left) >= Right;	
		end ">=";	   
		    
   function "<"(Left : in Float;	
                Right: in Integer) return Boolean is	
		begin  
		return Left < Float(Right);	
		end "<";	
		       
   function "<"(Left : in Integer;	
                Right: in Float) return Boolean is	
		begin  
		return Float(Left) < Right;	
		end "<";	   
		    
   function "<="(Left : in Float;	
                Right: in Integer) return Boolean is	
		begin  
		return Left <= Float(Right);	
		end "<=";	
		       
   function "<="(Left : in Integer;	
                Right: in Float) return Boolean is	
		begin  
		return Float(Left) <= Right;	
		end "<=";	   
		    
   function "="(Left : in Float;	
                Right: in Integer) return Boolean is	
		begin  
		return Left = Float(Right);	
		end "=";
		       
   function "="(Left : in Integer;	
                Right: in Float) return Boolean is	
		begin  
		return Float(Left) = Right;	
		end "=";
end Gusjo;
