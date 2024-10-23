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

float benchmark(function_t function, int duration, int minRuns) {
    int runs = minRuns, runTime = 0;
    for(int i = 0; i < 10; i++) {
        runTime = getTime(function, runs);

        // If we hit the desired benchmarking time, break
        if(runTime > duration * .95f && runTime < duration * 1.05f)
            break;

        // If the function takes too long to run, return results from minRuns
        runs *= (float)duration / (float)runTime;
        
        if(runs < minRuns) {
            runs = minRuns;
            break;
        }
    }

    runTime = getTime(function, runs);
    
    return (float)runTime / (float)runs;
}