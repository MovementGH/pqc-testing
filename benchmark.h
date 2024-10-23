#ifndef _BENCH_H_
#define _BENCH_H_

typedef void (*function_t) ();

float benchmark(function_t function, int duration, int minRuns);

#endif