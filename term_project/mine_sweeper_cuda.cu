#include <cuda.h>
#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <vector>
#include <unordered_map>
#include <map>
#include <queue>
#include <string.h>
#include <time.h>
#include <iomanip>
#include <pthread.h>
#include <algorithm>
#include <semaphore.h>
#include <condition_variable>
#include <vector>
#include <cuda.h>
#include <cuda_runtime.h>

#define UNKNOWN 0
#define OPEN 1
#define FINISH 2
#define BOMB -1
#define FLAG -1

#define BLOCK_DIM 25
#define CHUNK_DIM 2

using namespace std;

// Function prototypes
__device__ bool inMap(int m, int n, int numOfRows, int numOfCols);
bool inMap_gloabal(int m, int n, int numOfRows, int numOfCols);
__global__ void random_select(int *device_current_select, int *device_truth_map, int *device_current_map, int *device_select_list, int numOfRows, int numOfCols);
__global__ void detect_bomb(int *device_truth_map, int *device_current_map, int *device_select_list, int numOfRows, int numOfCols, int true_bomb_count, int *device_current_bomb_count);
bool compare_map();
void initialize(int numOfBombs);

// Global varirables
int *truth_map, *current_map;
int *m_select_list;
int *device_truth_map, *device_current_map;
int current_bomb_count;
int *device_current_bomb_count;
int *return_map;
int *device_current_select;

int NUM_THREADS;
int numOfRows, numOfCols;
int true_bomb_count;
int current_select = 0;
int bomb_count;
vector<int> select_list;
int *device_select_list;

bool inMap_gloabal(int m, int n, int numOfRows, int numOfCols)
{
    if (m < 0 || m >= numOfRows || n < 0 || n >= numOfCols)
        return false;
    return true;
}
__device__ bool inMap(int m, int n, int numOfRows, int numOfCols)
{
    if (m < 0 || m >= numOfRows || n < 0 || n >= numOfCols)
        return false;
    return true;
}
__global__ void random_select(int *device_current_select, int *device_truth_map, int *device_current_map, int *device_select_list, int numOfRows, int numOfCols)
{

    int m = -1;
    int n = -1;

    // will pass all bomb now !!
    int numOfGrids = numOfRows * numOfCols;
    while (*device_current_select < numOfGrids)
    {
        m = device_select_list[*device_current_select] / numOfCols;
        n = device_select_list[(*device_current_select)++] % numOfCols;
        if (device_current_map[m * numOfCols + n] == UNKNOWN && device_truth_map[m * numOfCols + n] != BOMB)
        {
            device_current_map[m * numOfCols + n] = OPEN;
            break;
        }
    }
}

__device__ void set_flag(int *device_current_map, int m, int n, int numOfRows, int numOfCols)
{
    device_current_map[m * numOfCols + n] = FLAG;
}

__device__ void openGrid(int *device_current_map, int m, int n, int numOfRows, int numOfCols)
{
    device_current_map[m * numOfCols + n] = OPEN;
}

bool compare_map()
{
    for (int i = 0; i < numOfRows; i++)
    {
        for (int j = 0; j < numOfCols; j++)
        {
            if (truth_map[i * numOfCols + j] == BOMB && truth_map[i * numOfCols + j] != return_map[i * numOfCols + j])
            {
                cout << "Truth_map : " << endl;
                for (int m = 0; m < numOfRows; m++)
                {
                    for (int n = 0; n < numOfCols; n++)
                    {
                        cout << setfill(' ') << setw(3) << truth_map[m * numOfCols + n] << " ";
                    }
                    cout << endl;
                }
                cout << "Current map : " << endl;
                for (int m = 0; m < numOfRows; m++)
                {
                    for (int n = 0; n < numOfCols; n++)
                    {
                        cout << setfill(' ') << setw(3) << return_map[m * numOfCols + n] << " ";
                    }
                    cout << endl;
                }
                cout << "First error : row " + to_string(i) + " column " + to_string(j) << endl;

                return false;
            }
        }
    }
    return true;
}

__global__ void detect_bomb(int *device_truth_map, int *device_current_map, int *device_select_list, int numOfRows, int numOfCols, int true_bomb_count, int *device_current_bomb_count)
{
    int thisX = (blockIdx.x * blockDim.x + threadIdx.x) * CHUNK_DIM;
    int thisY = (blockIdx.y * blockDim.y + threadIdx.y) * CHUNK_DIM;

    __shared__ bool changed;
    changed = true;

    // while (*device_current_bomb_count < true_bomb_count)
    // {
    //     __syncthreads();
    //     if (blockIdx.x == 0 && threadIdx.x == 0 && blockIdx.y == 0 && threadIdx.y == 0)
    //     {
    //         random_select(&device_current_select, device_truth_map, device_current_map, device_select_list, numOfRows, numOfCols);
    //     }
    //     if (threadIdx.x == 0 && threadIdx.y == 0)
    //     {
    //         changed = true;
    //     }
    //     __syncthreads();

    while (changed)
    {
        __syncthreads();
        if (threadIdx.x == 0 && threadIdx.y == 0)
        {
            changed = false;
        }
        __syncthreads();
        for (int row = thisY; row < thisY + CHUNK_DIM && row < numOfRows; row++)
        {
            for (int col = thisX; col < thisX + CHUNK_DIM && col < numOfCols; col++)
            {
                if (device_current_map[row * numOfCols + col] == OPEN && device_truth_map[row * numOfCols + col] != BOMB)
                {
                    int iterateRow[8] = {-1, -1, -1, 0, 0, 1, 1, 1}, iterateCol[8] = {-1, 0, 1, -1, 1, -1, 0, 1};
                    int grid_num = device_truth_map[row * numOfCols + col];
                    int flag_num = 0, unknown_num = 0;
                    for (int i = 0; i < 8; i++)
                    {
                        int detect_row = row + iterateRow[i], detect_col = col + iterateCol[i];
                        if (!inMap(detect_row, detect_col, numOfRows, numOfCols))
                            continue;
                        if (device_current_map[detect_row * numOfCols + detect_col] == FLAG)
                            flag_num++;
                    }
                    for (int i = 0; i < 8; i++)
                    {
                        int detect_row = row + iterateRow[i], detect_col = col + iterateCol[i];
                        if (!inMap(detect_row, detect_col, numOfRows, numOfCols))
                            continue;
                        if (device_current_map[detect_row * numOfCols + detect_col] == UNKNOWN)
                            unknown_num++;
                    }

                    if (unknown_num + flag_num == grid_num)
                    {
                        for (int i = 0; i < 8; i++)
                        {
                            int detect_row = row + iterateRow[i], detect_col = col + iterateCol[i];
                            if (!inMap(detect_row, detect_col, numOfRows, numOfCols))
                                continue;
                            if (device_current_map[detect_row * numOfCols + detect_col] == UNKNOWN)
                            {
                                set_flag(device_current_map, detect_row, detect_col, numOfRows, numOfCols);
                                atomicAdd(device_current_bomb_count, 1);
                                changed = true;
                            }
                        }
                        device_current_map[row * numOfCols + col] = FINISH;
                    }
                    else if (flag_num == grid_num)
                    {
                        for (int i = 0; i < 8; i++)
                        {
                            int detect_row = row + iterateRow[i], detect_col = col + iterateCol[i];
                            if (!inMap(detect_row, detect_col, numOfRows, numOfCols))
                                continue;
                            if (device_current_map[detect_row * numOfCols + detect_col] == UNKNOWN)
                            {
                                openGrid(device_current_map, detect_row, detect_col, numOfRows, numOfCols);
                                changed = true;
                            }
                        }
                        device_current_map[row * numOfCols + col] = FINISH;
                    }
                }
            }
        }
        __syncthreads();
    }
}

int countNeighborBombs(int row, int col)
{
    int result = 0;
    int iterateRow[8] = {-1, -1, -1, 0, 0, 1, 1, 1}, iterateCol[8] = {-1, 0, 1, -1, 1, -1, 0, 1};
    for (int i = 0; i < 8; i++)
    {
        int curRow = row + iterateRow[i], curCol = col + iterateCol[i];
        if (!inMap_gloabal(curRow, curCol, numOfRows, numOfCols))
            continue;
        if (truth_map[curRow * numOfCols + curCol] == BOMB)
            result++;
    }
    return result;
}

void initialize(int numOfBombs)
{
    int numOfGrids = numOfRows * numOfCols;
    current_bomb_count = 0;
    m_select_list = (int *)malloc(sizeof(int) * numOfGrids);
    current_map = (int *)calloc(numOfGrids, sizeof(int));
    truth_map = (int *)calloc(numOfGrids, sizeof(int));
    vector<int> bombCandidates(numOfGrids);
    for (int i = 0; i < numOfGrids; i++)
    {
        bombCandidates[i] = i;
    }
    true_bomb_count = numOfBombs;
    random_shuffle(bombCandidates.begin(), bombCandidates.end());
    // first numOfBombs numbers would be bomb indexes.
    for (int i = 0; i < numOfBombs; i++)
    {
        truth_map[bombCandidates[i]] = BOMB;
    }
    for (int i = 0; i < numOfRows; i++)
    {
        for (int j = 0; j < numOfCols; j++)
        {
            if (truth_map[i * numOfCols + j] != BOMB)
                truth_map[i * numOfCols + j] = countNeighborBombs(i, j);
        }
    }
    // initialize random select list
    for (int i = 0; i < numOfGrids; i++)
        select_list.push_back(i);

    random_shuffle(select_list.begin(), select_list.end());
    for (int i = 0; i < numOfGrids; i++)
        m_select_list[i] = select_list[i];

    cudaMalloc(&device_truth_map, sizeof(int) * numOfGrids);
    cudaMalloc(&device_current_map, sizeof(int) * numOfGrids);
    cudaMalloc(&device_select_list, sizeof(int) * numOfGrids);
    cudaMalloc(&device_current_bomb_count, sizeof(int) * 1);
    cudaMalloc(&device_current_select, sizeof(int) * 1);

    cudaMemcpy(device_truth_map, truth_map, sizeof(int) * numOfGrids, cudaMemcpyHostToDevice);
    cudaMemcpy(device_current_map, current_map, sizeof(int) * numOfGrids, cudaMemcpyHostToDevice);
    cudaMemcpy(device_select_list, m_select_list, sizeof(int) * numOfGrids, cudaMemcpyHostToDevice);
    cudaMemset(device_current_bomb_count, 0, sizeof(int));
    cudaMemset(device_current_select, 0, sizeof(int));
    // cudaMemcpy(device_current_bomb_count, current_bomb_count, sizeof(int) * 1, cudaMemcpyHostToDevice);
    // cudaMemcpy(device_changed, changed, sizeof(bool) * 1, cudaMemcpyHostToDevice);
}

int main(int argc, char **argv)
{
    numOfRows = stoi(argv[1]);
    numOfCols = stoi(argv[2]);
    NUM_THREADS = stoi(argv[4]);
    dim3 threadsPerBlock(BLOCK_DIM, BLOCK_DIM);
    dim3 numBlocks(numOfCols / (threadsPerBlock.x * CHUNK_DIM), numOfRows / (threadsPerBlock.y * CHUNK_DIM));
    return_map = (int *)malloc(sizeof(int) * numOfRows * numOfCols);
    initialize(stoi(argv[3]));

    clock_t a, b;
    a = clock();
    while (current_bomb_count < true_bomb_count)
    {
        random_select<<<1, 1>>>(device_current_select, device_truth_map, device_current_map, device_select_list, numOfRows, numOfCols);
        detect_bomb<<<numBlocks, threadsPerBlock>>>(device_truth_map, device_current_map, device_select_list, numOfRows, numOfCols, true_bomb_count, device_current_bomb_count);
        cudaMemcpy(&current_bomb_count, device_current_bomb_count, sizeof(int), cudaMemcpyDeviceToHost);
    }
    cudaDeviceSynchronize();
    b = clock();
    cout << "time: " << double(b - a) / CLOCKS_PER_SEC << endl;
    cudaMemcpy(return_map, device_current_map, sizeof(int) * numOfRows * numOfCols, cudaMemcpyDeviceToHost);
    bool result = compare_map();
    cudaFree(device_truth_map);
    cudaFree(device_current_map);
    cudaFree(device_select_list);
    free(truth_map);
    free(current_map);
    free(m_select_list);
    if (result)
    {
        char cmd[30];
        strcpy(cmd, "figlet Congratulation!!!");
        cout << cmd << endl;
        // system(cmd);
    }
    return 0;
}