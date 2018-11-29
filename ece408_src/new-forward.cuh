
#ifndef MXNET_OPERATOR_NEW_FORWARD_CUH_
#define MXNET_OPERATOR_NEW_FORWARD_CUH_

#include <mxnet/base.h>

namespace mxnet
{
namespace op
{

#define TILE_WIDTH 24  // FIXME change this for performance (check computibility and number of threads per block allowed)

__global__ void forward_kernel(float *y, const float *x, const float *k, const int B, const int M, const int C, const int H, const int W, const int K)
{

    /*
    Modify this function to implement the forward pass described in Chapter 16.
    We have added an additional dimension to the tensors to support an entire mini-batch
    The goal here is to be correct AND fast.
    We have some nice #defs for you below to simplify indexing. Feel free to use them, or create your own.
    */

    const int H_out = H - K + 1;
    const int W_out = W - K + 1;

    int W_grid = ceil((double)W_out / TILE_WIDTH);
    // int W_grid = W_out / TILE_WIDTH;
    // if (W_out % TILE_WIDTH > 0) ++W_grid;


    #define y4d(i3, i2, i1, i0) y[(i3) * (M * H_out * W_out) + (i2) * (H_out * W_out) + (i1) * (W_out) + i0]
    #define x4d(i3, i2, i1, i0) x[(i3) * (C * H * W) + (i2) * (H * W) + (i1) * (W) + i0]
    #define k4d(i3, i2, i1, i0) k[(i3) * (C * K * K) + (i2) * (K * K) + (i1) * (K) + i0]

    int b = blockIdx.x;
    int m = blockIdx.y;
    int h = (blockIdx.z / W_grid) * TILE_WIDTH + threadIdx.y;
    int w = (blockIdx.z % W_grid) * TILE_WIDTH + threadIdx.x;

    float result = 0.0;
    if (h < H_out && w < W_out) {
      for (int c = 0; c < C; ++c) {
        for (int p = 0; p < K; ++p) {
          for (int q = 0; q < K; ++q) {
            result += x4d(b, c, h + p, w + q) * k4d(m, c, p, q);
          }
        }
      }
      y4d(b, m, h, w) = result;
    }

    #undef y4d
    #undef x4d
    #undef k4d
}

/*
   This function is called by new-inl.h
   Any code you write should be executed by this function.
   For ECE408, we only expect the float version of the operator to be called, so here we specialize with only floats.
*/
template <>
void forward<gpu, float>(mshadow::Tensor<gpu, 4, float> &y, const mshadow::Tensor<gpu, 4, float> &x, const mshadow::Tensor<gpu, 4, float> &w)
{

    // Use mxnet's CHECK_EQ to do assertions.
    // Remove this assertion when you do your implementation!
    /* CHECK_EQ(0, 1) << "Remove this line and replace with your implementation"; */

    // Extract the tensor dimensions into B,M,C,H,W,K
    const int B = x.shape_[0];  // Number of images in a batch
    const int M = y.shape_[1];  // Number of output feature maps
    const int C = x.shape_[1];  // Number of input feature maps
    const int H = x.shape_[2];  // Height of input image
    const int W = x.shape_[3];  // Width of input image
    const int K = w.shape_[3];  // Width of square filter

    // Set the kernel dimensions
    const int H_out = H - K + 1;
    const int W_out = W - K + 1;
    // int W_grid = W_out / TILE_WIDTH;
    // if (W_out % TILE_WIDTH > 0) ++W_grid;
    // int H_grid = H_out / TILE_WIDTH;
    // if (H_out % TILE_WIDTH > 0) ++H_grid;
    // const int Z = W_grid * H_grid;
    int W_grid = ceil((double)W_out/TILE_WIDTH); // number of horizontal tiles per output map
    int H_grid = ceil((double)H_out/TILE_WIDTH); // number of vertical tiles per output map
    int Z = H_grid * W_grid;

    dim3 gridDim(B, M, Z);
    dim3 blockDim(TILE_WIDTH, TILE_WIDTH, 1);

    // Call the kernel
    forward_kernel<<<gridDim, blockDim>>>(y.dptr_,x.dptr_,w.dptr_, B,M,C,H,W,K);

    // Use MSHADOW_CUDA_CALL to check for CUDA runtime errors.
    MSHADOW_CUDA_CALL(cudaDeviceSynchronize());

}

/*
    This tells mxnet how to do an op when it's not a float.
    This is not used in the ECE408 project
*/
template <typename gpu, typename DType>
void forward(mshadow::Tensor<gpu, 4, DType> &y, const mshadow::Tensor<gpu, 4, DType> &x, const mshadow::Tensor<gpu, 4, DType> &w)
{
    CHECK_EQ(0,1) << "Remove this line and replace it with your implementation.";
}
}
}

#endif
