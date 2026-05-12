--  Data utilities implementation
with Ada.Integer_Text_Io;
with Ada.Float_Text_Io;
with Ada.Strings;
with Ada.Strings.Fixed;

package body Gusjo.Data is

   use Ada.Strings;
   use Ada.Strings.Fixed;

   function Parse_Value(Str : String) return Value_Type is
      Trimmed : constant String := Trim(Str, Both);
      Val : Integer;
      Fval : Float;
      Last : Integer;
   begin
      --  Try to parse as Integer first
      begin
         Ada.Integer_Text_Io.Get(Trimmed, Val, Last);
         if Last = Trimmed'Last then
            return (Kind => Integer_Type, Int_Val => Val);
         end if;
      exception
         when others => null;
      end;

      --  Try to parse as Float
      begin
         Ada.Float_Text_Io.Get(Trimmed, Fval, Last);
         if Last = Trimmed'Last then
            return (Kind => Float_Type, Float_Val => Fval);
         end if;
      exception
         when others => null;
      end;

      --  Fall back to String
      return (Kind => String_Type, Str_Val => To_Unbounded_String(Trimmed));
   end Parse_Value;

   function To_Integer(Val : Value_Type) return Integer is
   begin
      case Val.Kind is
         when Integer_Type =>
            return Val.Int_Val;
         when Float_Type =>
            return Integer(Val.Float_Val);
         when String_Type =>
            raise Conversion_Error with "Cannot convert string to integer";
      end case;
   end To_Integer;

   function To_Float(Val : Value_Type) return Float is
   begin
      case Val.Kind is
         when Integer_Type =>
            return Float(Val.Int_Val);
         when Float_Type =>
            return Val.Float_Val;
         when String_Type =>
            raise Conversion_Error with "Cannot convert string to float";
      end case;
   end To_Float;

   function To_String(Val : Value_Type) return String is
   begin
      case Val.Kind is
         when Integer_Type =>
            return Integer'Image(Val.Int_Val);
         when Float_Type =>
            return Float'Image(Val.Float_Val);
         when String_Type =>
            return To_String(Val.Str_Val);
      end case;
   end To_String;

end Gusjo.Data;
