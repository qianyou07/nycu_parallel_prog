#define _XOPEN_SOURCE 600
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

#define UNKNOWN 0
#define OPEN 1
#define FINISH 2
#define BOMB -1
#define FLAG -1

using namespace std;

// Function prototypes
bool inMap(int m, int n);
int open_zero(int m, int n, int threadId);
void random_open_zero(int m, int n);
void random_select(int threadId);
void set_flag(int m, int n);
void openGrid(int m, int n, int threadId);
bool detect_bomb(int threadId);
bool compare_map();
void initialize(int numOfBombs);

// Global varirables
pthread_barrier_t barrier;
vector<vector<int>> truth_map;
vector<vector<int>> current_map;
vector<vector<int>> current_map2;

int NUM_THREADS;
bool changed = true;
int numOfRows, numOfCols;
int true_bomb_count;
int current_select = 0;
int bomb_count;
vector<int> select_list;

bool inMap(int m, int n)
{
    if (m < 0 || m >= numOfRows || n < 0 || n >= numOfCols)
        return false;
    return true;
}
void random_select()
{

    int m = -1;
    int n = -1;

    // will pass all bomb now !!
    int numOfGrids = numOfRows * numOfCols;
    while (current_select < numOfGrids)
    {
        m = select_list[current_select] / numOfCols;
        n = select_list[current_select++] % numOfCols;
        if (current_map[m][n] == UNKNOWN && truth_map[m][n] != BOMB)
        {
            current_map[m][n] = OPEN;
            current_map2[m][n] = OPEN;
            break;
        }
    }

    if (m == -1)
    {
        cout << "Go through all grid but still random select" << endl;
        return;
    }
}

void set_flag(int m, int n)
{
    current_map2[m][n] = FLAG;
}

void openGrid(int m, int n)
{
    current_map2[m][n] = OPEN;
}

bool compare_map()
{
    for (int i = 0; i < numOfRows; i++)
    {
        for (int j = 0; j < numOfCols; j++)
        {
            if (truth_map[i][j] == BOMB && truth_map[i][j] != current_map[i][j])
            {
                cout << "Truth_map : " << endl;
                for (int m = 0; m < numOfRows; m++)
                {
                    for (int n = 0; n < numOfCols; n++)
                    {
                        cout << setfill(' ') << setw(3) << truth_map[m][n] << " ";
                    }
                    cout << endl;
                }
                cout << "Current map : " << endl;
                for (int m = 0; m < numOfRows; m++)
                {
                    for (int n = 0; n < numOfCols; n++)
                    {
                        cout << setfill(' ') << setw(3) << current_map[m][n] << " ";
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

void *task(void *arg)
{
    int threadId = *((int *)arg);
    while (changed)
    {
        for (int row = threadId; row < numOfRows; row += NUM_THREADS)
        {
            for (int col = 0; col < numOfCols; col++)
            {
                if (current_map[row][col] == OPEN && truth_map[row][col] != BOMB)
                {
                    int iterateRow[8] = {-1, -1, -1, 0, 0, 1, 1, 1}, iterateCol[8] = {-1, 0, 1, -1, 1, -1, 0, 1};
                    int grid_num = truth_map[row][col];
                    int flag_num = 0, unknown_num = 0;
                    for (int i = 0; i < 8; i++)
                    {
                        int detect_row = row + iterateRow[i], detect_col = col + iterateCol[i];
                        if (!inMap(detect_row, detect_col))
                            continue;
                        if (current_map[detect_row][detect_col] == FLAG)
                            flag_num++;
                        else if (current_map[detect_row][detect_col] == UNKNOWN)
                            unknown_num++;
                    }
                    if (unknown_num + flag_num == grid_num)
                    {
                        for (int i = 0; i < 8; i++)
                        {
                            int detect_row = row + iterateRow[i], detect_col = col + iterateCol[i];
                            if (!inMap(detect_row, detect_col))
                                continue;
                            if (current_map[detect_row][detect_col] == UNKNOWN)
                                set_flag(detect_row, detect_col);
                        }
                        current_map[row][col] = FINISH;
                    }
                    else if (flag_num == grid_num)
                    {
                        for (int i = 0; i < 8; i++)
                        {
                            int detect_row = row + iterateRow[i], detect_col = col + iterateCol[i];
                            if (!inMap(detect_row, detect_col))
                                continue;
                            if (current_map[detect_row][detect_col] == UNKNOWN)
                                openGrid(detect_row, detect_col);
                        }
                        current_map[row][col] = FINISH;
                    }
                }
            }
        }
        pthread_barrier_wait(&barrier);

        if (threadId == 0)
        {
            changed = false;
            bomb_count = 0;
            for (int i = 0; i < numOfRows; i++)
            {
                for (int j = 0; j < numOfCols; j++)
                {
                    if (current_map2[i][j] != current_map[i][j])
                    {
                        changed = true;
                        current_map[i][j] = current_map2[i][j];
                    }
                    if (current_map[i][j] == BOMB)
                        bomb_count++;
                }
            }
            if (!changed)
            {
                random_select();
                changed = true;
            }
        }

        pthread_barrier_wait(&barrier);
        if (bomb_count >= true_bomb_count)
            return NULL;
    }
    return NULL;
}

int countNeighborBombs(int row, int col)
{
    int result = 0;
    int iterateRow[8] = {-1, -1, -1, 0, 0, 1, 1, 1}, iterateCol[8] = {-1, 0, 1, -1, 1, -1, 0, 1};
    for (int i = 0; i < 8; i++)
    {
        int curRow = row + iterateRow[i], curCol = col + iterateCol[i];
        if (inMap(curRow, curCol) && truth_map[curRow][curCol] == BOMB)
            result++;
    }
    return result;
}

void initialize(int numOfBombs)
{
    // initialize current map
    current_map.resize(numOfRows);
    current_map2.resize(numOfRows);
    for (int i = 0; i < numOfRows; i++)
    {
        current_map[i].resize(numOfCols, UNKNOWN);
        current_map2[i].resize(numOfCols, UNKNOWN);
    }

    // initialize truth map
    truth_map.resize(numOfRows);
    for (int i = 0; i < numOfRows; i++)
    {
        truth_map[i].resize(numOfCols, 0);
    }

    int numOfGrids = numOfRows * numOfCols;
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
        truth_map[bombCandidates[i] / numOfCols][bombCandidates[i] % numOfCols] = BOMB;
    }
    for (int i = 0; i < numOfRows; i++)
    {
        for (int j = 0; j < numOfCols; j++)
        {
            if (truth_map[i][j] != BOMB)
                truth_map[i][j] = countNeighborBombs(i, j);
        }
    }
    // initialize random select list
    for (int i = 0; i < numOfGrids; i++)
        select_list.push_back(i);

    random_shuffle(select_list.begin(), select_list.end());
}

int main(int argc, char **argv)
{
    numOfRows = stoi(argv[1]);
    numOfCols = stoi(argv[2]);
    NUM_THREADS = stoi(argv[4]);
    pthread_t threads[NUM_THREADS];
    pthread_barrier_init(&barrier, NULL, NUM_THREADS);
    initialize(stoi(argv[3]));
    clock_t a, b;
    a = clock();
    random_select();
    int num[NUM_THREADS];
    for (int t = 0; t < NUM_THREADS; t++)
    {
        num[t] = t;
        pthread_create(&threads[t], NULL, task, (void *)&num[t]);
    }

    for (int t = 0; t < NUM_THREADS; t++)
    {
        pthread_join(threads[t], NULL);
    }
    b = clock();
    pthread_barrier_destroy(&barrier);
    cout << "time1: " << double(b - a) / CLOCKS_PER_SEC << endl;
    bool result = compare_map();
    if (result)
    {
        char cmd[30];
        strcpy(cmd, "figlet Congratulation!!!");
        // cout<<cmd<<endl;
        system(cmd);
    }
    return 0;
}