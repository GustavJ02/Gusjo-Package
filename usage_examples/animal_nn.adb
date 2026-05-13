with Ada.Text_IO;          use Ada.Text_IO;
with Ada.Float_Text_IO;    use Ada.Float_Text_IO;

with Gusjo.Ai;             use Gusjo.Ai;
with Gusjo.Ai.Nn;          use Gusjo.Ai.Nn;
with Gusjo.Math;           use Gusjo.Math;
with Gusjo.Data.Frame;     use Gusjo.Data.Frame;
with Gusjo.Math.Linalg;    use Gusjo.Math.Linalg;

procedure Animal_Nn is

   DF : DataFrame_Type;

begin
   Put_Line("Loading animals dataset...");
   Load_CSV("python_comparison/animals.csv", DF);
   
   Put_Line("=== Data Preview ===");
   Display(DF, Max_Rows_Display => 5);

   Delete(DF);
end Animal_Nn;
