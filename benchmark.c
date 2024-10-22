#include <sys/time.h>
#include <unistd.h>
#include "benchmark.h"

int getTime(function_t func, int runs) {
    struct timeval start, end;
    gettimeofday(&start, NULL);

    for(int i = 0; i < runs; i++)
        func();

    gettimeofday(&end, NULL);

    return (end.tv_sec - start.tv_sec) * 1000 * 1000 + (end.tv_usec - start.tv_usec);
}

float benchmark(function_t function, int duration) {
    int runs = 1, cycles = 0, runTime = 0;
    do {
        runTime = getTime(function, runs);
        runs *= (float)duration / (float)runTime;
        cycles++;
    } while ((runTime < duration * .95f || runTime > duration * 1.05f) && cycles < 10);

    return (float)runTime / (float)runs;
}