with Gusjo.Math.Linalg;   use Gusjo.Math.Linalg;
with Gusjo.Math;          use Gusjo.Math;

package gusjo.ai.linreg is

   type LinReg_Model is private;
   
   function Train(X : Matrix; y : Column_Vector) return LinReg_Model;
   
   function Predict(model : LinReg_Model; X : Matrix) return Column_Vector;

   function Predict(model : LinReg_Model; X : Row_Vector) return Column_Vector;

   function R2_Score(model: LinReg_Model) return Float;

   function Weights(model: LinReg_Model) return Column_Vector;
   
private

   type LinReg_Model is
      record
         Weights : Column_Vector;
         R2      : Float;
      end record;
   
end gusjo.ai.linreg;