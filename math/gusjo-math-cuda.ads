with Interfaces.C;
with System;

package Gusjo.Math.CUDA is

   use type Interfaces.C.int;

   function CUDA_Available_C return Interfaces.C.int;
   pragma Import (C, CUDA_Available_C, "gusjo_cuda_available");

   function CUDA_Available return Boolean is
     (CUDA_Available_C /= 0);

   procedure CUDA_Matmul
     (A : in  System.Address;
      B : in  System.Address;
      C : in  System.Address;
      M : in  Interfaces.C.int;
      K : in  Interfaces.C.int;
      N : in  Interfaces.C.int);
   pragma Import (C, CUDA_Matmul, "gusjo_cuda_matmul");

end Gusjo.Math.CUDA;
