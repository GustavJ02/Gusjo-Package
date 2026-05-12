--  Data type definitions and utilities
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package Gusjo.Data is

   --  Supported column data types
   type Column_Kind is (Integer_Type, Float_Type, String_Type);

   --  Type for storing values with optional kind information
   type Value_Type(Kind : Column_Kind := String_Type) is record
      case Kind is
         when Integer_Type =>
            Int_Val : Integer;
         when Float_Type =>
            Float_Val : Float;
         when String_Type =>
            Str_Val : Unbounded_String;
      end case;
   end record;

   --  Array of values
   type Value_Type_Array is array(Natural range <>) of Value_Type;

   --  Array of integers for column indices
   type Integer_Array is array(Natural range <>) of Integer;

   --  Try to parse a string to a value, inferring type (Int → Float → String)
   function Parse_Value(Str : String) return Value_Type;

   --  Convert Value_Type to Integer (raises exception if not convertible)
   function To_Integer(Val : Value_Type) return Integer;

   --  Convert Value_Type to Float (raises exception if not convertible)
   function To_Float(Val : Value_Type) return Float;

   --  Convert Value_Type to String
   function To_String(Val : Value_Type) return String;

   --  Exceptions for conversion errors
   Conversion_Error : exception;

end Gusjo.Data;
