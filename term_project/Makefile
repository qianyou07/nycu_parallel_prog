all: cuda pthread

cuda: mine_sweeper_cuda.cu
	nvcc -std=c++11 --device-c -gencode=arch=compute_61,code=sm_61 -Xcompiler '-fPIC' -g -O3 -c mine_sweeper_cuda.cu -o mine_sweeper_cuda.o
	nvcc -std=c++11 -rdc=true -gencode=arch=compute_61,code=sm_61 -Xcompiler '-fPIC'  -o mine_sweeper_cuda mine_sweeper_cuda.o

pthread: mine_sweeper_pthread.cpp
	g++ -o mine_sweeper_pthread -std=c++11 -lpthread -Wall -O3 mine_sweeper_pthread.cpp

clean:
	rm mine_sweeper_cuda
	rm mine_sweeper_pthread