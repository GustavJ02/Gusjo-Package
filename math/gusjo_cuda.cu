#include <cuda_runtime.h>
#include <cublas_v2.h>

// cuBLAS handle — initialised once, reused
static cublasHandle_t handle = NULL;

extern "C" {

    int gusjo_cuda_available(void) {
        int device_count = 0;
        cudaError_t err = cudaGetDeviceCount(&device_count);
        return (err == cudaSuccess && device_count > 0) ? 1 : 0;
    }

    // Use cuBLAS SGEMM — highly optimised by Nvidia
    // cuBLAS uses column-major, so we swap A and B to handle row-major Ada arrays
    void gusjo_cuda_matmul(
        const float* A, const float* B, float* C,
        int M, int K, int N)
    {
        if (handle == NULL) cublasCreate(&handle);

        float *d_A, *d_B, *d_C;
        cudaMalloc(&d_A, M * K * sizeof(float));
        cudaMalloc(&d_B, K * N * sizeof(float));
        cudaMalloc(&d_C, M * N * sizeof(float));

        cudaMemcpy(d_A, A, M * K * sizeof(float), cudaMemcpyHostToDevice);
        cudaMemcpy(d_B, B, K * N * sizeof(float), cudaMemcpyHostToDevice);

        const float alpha = 1.0f, beta = 0.0f;

        // Swap A/B and M/N to convert row-major to column-major
        cublasSgemm(handle,
                    CUBLAS_OP_N, CUBLAS_OP_N,
                    N, M, K,
                    &alpha,
                    d_B, N,
                    d_A, K,
                    &beta,
                    d_C, N);

        cudaMemcpy(C, d_C, M * N * sizeof(float), cudaMemcpyDeviceToHost);

        cudaFree(d_A);
        cudaFree(d_B);
        cudaFree(d_C);
    }
}