with Gusjo.math.Linalg;   use Gusjo.Math.Linalg;
with Gusjo.Math;          use Gusjo.Math;

package body gusjo.ai.linreg is

   function Train(X : Matrix; y : Column_Vector) return LinReg_Model is
      Model : LinReg_Model;

      X_T, X_T_X, X_T_X_inv, X_T_y : Matrix;
      Weights_M, P_M, Y_M, Resid_M, Ones_M, Ymm_M : Matrix;

      Ones_C, Y_minus_mean : Column_Vector;

      N : Positive := Length(y);
      Sum_y, Mean_y, SS_res, SS_tot : Float;
   begin
      -- Normal equation: w = (X^T X)^{-1} X^T y
      X_T := Transpose(X);
      X_T_X := X_T * X;
      X_T_X_inv := Inverse(X_T_X);
      X_T_y := X_T * To_Matrix(y);

      Weights_M := X_T_X_inv * X_T_y;

      -- store weights as a Column_Vector in the model
      Model.Weights := To_Column_Vector(Weights_M);

      -- Predictions P = X * w
      P_M := X * Weights_M;

      -- Residuals = P - y
      Y_M := To_Matrix(y);
      Resid_M := P_M - Y_M;
      SS_res := L2_Norm(Resid_M) ** 2;

      -- Total sum of squares: sum (y - mean_y)^2
      Ones_M := Ones(N, 1);
      Ones_C := To_Column_Vector(Ones_M);
      Sum_y := Dot_Product(y, Ones_C);
      Mean_y := Sum_y / Float(N);

      Y_minus_mean := Copy(y);
      Axpy(Y_minus_mean, -Mean_y, Ones_C); -- Y_minus_mean := y - mean_y*1
      Ymm_M := To_Matrix(Y_minus_mean);
      SS_tot := L2_Norm(Ymm_M) ** 2;

      if SS_tot <= 0.0 then
         Model.R2 := 0.0;
      else
         Model.R2 := 1.0 - SS_res / SS_tot;
      end if;

      -- Clean up temporaries
      Delete(X_T);
      Delete(X_T_X);
      Delete(X_T_X_inv);
      Delete(X_T_y);
      Delete(Weights_M);
      Delete(P_M);
      Delete(Y_M);
      Delete(Resid_M);
      Delete(Ones_M);
      Delete(Ymm_M);
      Delete(Ones_C);
      Delete(Y_minus_mean);

      return Model;
   end Train;
   
   function Predict(model : LinReg_Model; X : Matrix) return Column_Vector is
      Predictions : Column_Vector;
      W : Matrix := To_Matrix(model.Weights);
      X_W : Matrix;
      Weights_Size : constant Positive := Length(model.Weights);
   begin
      -- Check that X has as many columns as the model has weights
      if Cols(X) /= Weights_Size then
         raise Dimension_Error with "Predict: X has " & Cols(X)'Image &
            " columns but model expects " & Weights_Size'Image;
      end if;

      X_W := X * W;
      Predictions := To_Column_Vector(X_W);
      Delete(W);
      Delete(X_W);
      return Predictions;
   end Predict;

   function Predict(model : LinReg_Model; X : Row_Vector) return Column_Vector is
      Predictions : Column_Vector;
      W : Matrix := To_Matrix(model.Weights);
      X_M : Matrix := To_Matrix(X);
      X_W : Matrix;
      Weights_Size : constant Positive := Length(model.Weights);
   begin
      -- Check that X has as many columns as the model has weights
      if Length(X) /= Weights_Size then
         raise Dimension_Error with "Predict: X has " & Length(X)'Image &
            " columns but model expects " & Weights_Size'Image;
      end if;

      X_W := X_M * W;
      Predictions := To_Column_Vector(X_W);
      Delete(W);
      Delete(X_M);
      Delete(X_W);
      return Predictions;
   end Predict;

   function R2_Score(model: LinReg_Model) return Float is
   begin
      return model.R2;
   end R2_Score;

   function Weights(model: LinReg_Model) return Column_Vector is
   begin
      return model.Weights;
   end Weights;

end gusjo.ai.linreg;