#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <api.h>
#include "benchmark.h"

#define MLEN 86
#define BENCHMARK_LENGTH 1000000

unsigned char *sm, *pk, *sk, *m, *m2;
unsigned long long smlen, pmlen;

void setup() {
    m = calloc(MLEN, sizeof(unsigned char));
    m2 = calloc(MLEN, sizeof(unsigned char));
    sm = calloc(MLEN + CRYPTO_BYTES, sizeof(unsigned char));
    pk = malloc(CRYPTO_PUBLICKEYBYTES * sizeof(unsigned char));
    sk = malloc(CRYPTO_SECRETKEYBYTES * sizeof(unsigned char));
    srand((unsigned int)time(NULL));
    crypto_sign_keypair(pk, sk);
    for(int i = 0; i < MLEN; i++)
        m[i] = (unsigned char)rand();
}

void sign() {
    crypto_sign(sm, &smlen, m, MLEN, sk);
}

void verify() {
    if(crypto_sign_open(m2, &pmlen, sm, smlen, pk) != 0) {
        printf("Verification of signature failed!\n");
        abort();
    }
}

int main() {
    setup();

    float signTime = benchmark(sign, BENCHMARK_LENGTH);
    float verifyTime = benchmark(verify, BENCHMARK_LENGTH);

    printf("Public Key Size: %d\n", CRYPTO_PUBLICKEYBYTES);
    printf("Private Key Size: %d\n", CRYPTO_SECRETKEYBYTES);
    printf("Message Size: %d\n", MLEN);
    printf("Signature Size: %d\n", smlen);
    printf("Signs: %.2f/s\n", 1000000.f / signTime);
    printf("Verifies: %.2f/s\n", 1000000.f / verifyTime);
}