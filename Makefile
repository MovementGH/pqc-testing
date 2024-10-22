CC=gcc
CFLAGS=-O3
LDFLAGS=

# General Purpose
benchmark.o: benchmark.c
	$(CC) $(CFLAGS) -c -o benchmark.o benchmark.c

# MAYO Tests
MAYO_TESTS=mayo_1.test mayo_2.test mayo_3.test mayo_5.test

MAYO-C:
	git clone https://github.com/PQCMayo/MAYO-C

MAYO-C/build/src/libmayo_common_sys.a: MAYO-C
	cd MAYO-C && mkdir -p build && cd build && cmake -DENABLE_STRICT=OFF .. && make -j

mayo_%.o: MAYO-C test.c
	$(CC) -c $(CFLAGS) -IMAYO-C/src/mayo_$*/ -o $@ test.c

mayo_%.test: mayo_%.o benchmark.o MAYO-C/build/src/libmayo_common_sys.a
	$(CC) -LMAYO-C/build/src -o $@ mayo_$*.o benchmark.o -lmayo_$*_nistapi -lmayo_$* -lmayo_common_sys

mayo: $(MAYO_TESTS)

# PQOV Tests
PQOV_TESTS=pqov_Ip.test pqov_Ip_pkc.test pqov_Ip_pkc_skc.test pqov_III.test pqov_III_pkc.test pqov_III_pkc_skc.test pqov_Is.test pqov_Is_pkc.test pqov_Is_pkc_skc.test pqov_V.test pqov_V_pkc.test pqov_V_pkc_skc.test
PQOV=pqov-src/pqov_nist_submission/Optimized_Implementation/avx2
PQOV_CFLAGS=-O3 -std=c99 -fno-omit-frame-pointer -mavx2 -maes

pqov-src:
	git clone https://github.com/pqov/pqov pqov-src

$(PQOV)/Makefile: pqov-src
	cd pqov-src && python3 create_nist_project.py > /dev/null

libpqov_%.a: $(PQOV)/Makefile
	for file in $(PQOV)/$*/*.c; do $(CC) -c $(PQOV_CFLAGS) -o $${file%.c}.o $${file}; done
	ar -crs libpqov_$*.a $(PQOV)/$*/*.o

pqov_%.o: $(PQOV)/Makefile test.c
	$(CC) -c $(CFLAGS) -I$(PQOV)/$* -o $@ test.c

pqov_%.test: pqov-src pqov_%.o benchmark.o libpqov_%.a
	$(CC) -L. -o $@ pqov_$*.o benchmark.o -lpqov_$* -lcrypto

pqov: $(PQOV_TESTS)

# Falcon Tests
FALCON_TESTS=falcon512.test falcon1024.test

falcon-round3:
	wget https://falcon-sign.info/falcon-round3.zip
	unzip falcon-round3.zip
	rm falcon-round3.zip

libfalcon%.a: falcon-round3
	make -C falcon-round3/Optimized_Implementation/falcon$*/falcon$*avx2 -j
	rm falcon-round3/Optimized_Implementation/falcon$*/falcon$*avx2/build/PQCgenKAT_sign.o
	ar -crs libfalcon$*.a falcon-round3/Optimized_Implementation/falcon$*/falcon$*avx2/build/*.o

falcon%.o: falcon-round3 test.c
	$(CC) -c $(CFLAGS) -Ifalcon-round3/Optimized_Implementation/falcon$*/falcon$*avx2 -o $@ test.c

falcon%.test: falcon%.o benchmark.o libfalcon%.a
	$(CC) -L. falcon$*.o benchmark.o -lfalcon$* -o $@

falcon: $(FALCON_TESTS)

# CROSS
CROSS=CROSS_submission_package_v1.2/Reference_Implementation
CROSS_TESTS = $(shell echo cross_{RSDP,RSDPG}-{SIG_SIZE,BALANCED,SPEED}-CATEGORY_{1,3,5}.test)
define CROSS_FLAGS
$(shell echo $(1) | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) printf("-D%s=1 ", $$i)}')
endef

CROSS_submission_package_v1.2:
	wget https://www.cross-crypto.com/CROSS_submission_package_v1.2.zip
	unzip CROSS_submission_package_v1.2.zip
	rm CROSS_submission_package_v1.2.zip
	cp CROSS_submission_package_v1.2/Optimized_Implementation/lib/CROSS.c CROSS_submission_package_v1.2/Reference_Implementation/lib/CROSS.c
	cp CROSS_submission_package_v1.2/Optimized_Implementation/include/* CROSS_submission_package_v1.2/Reference_Implementation/include


libcross_%.a: CROSS_submission_package_v1.2
	for file in $(CROSS)/lib/*.c; do \
		$(CC) -c -I$(CROSS)/include -march=native -O3 -g3 $(call CROSS_FLAGS, $*) -o $${file%.c}_$*.o $${file};\
	done
	ar -crs libcross_$*.a $(CROSS)/lib/*_$*.o

cross_%.o: CROSS_submission_package_v1.2
	$(CC) -c $(CFLAGS) -I$(CROSS)/include $(call CROSS_FLAGS, $*) -o $@ test.c

cross_%.test: cross_%.o benchmark.o libcross_%.a
	$(CC) -L. cross_$*.o benchmark.o -lcross_$* -o $@

cross: $(CROSS_TESTS)

# General Purpose
.DEFAULT_GOAL := tests

tests: cross mayo pqov falcon

test:
	for file in *.test; do echo "========== $${file%.test} =========="; ./$$file; echo ""; done > results.txt

clean:
	rm -f *.o *.test *.a results.txt

realclean: clean
	rm -rf falcon-round3 MAYO-C pqov-src CROSS_submission_package_v1.2