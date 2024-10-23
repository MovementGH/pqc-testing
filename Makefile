CC=gcc
CFLAGS=-O3 -flto
LDFLAGS=-flto
ALGORITHMS=mayo cross falcon pqov less meds

define GET_FLAGS
$(shell echo $(1) | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) printf("-D%s=1 ", $$i)}')
endef

# General Purpose
.DEFAULT_GOAL := tests

benchmark.o: benchmark.c
	$(CC) $(CFLAGS) -c -o benchmark.o benchmark.c

tests: ${ALGORITHMS}

test:
	for file in *.test; do echo "========== $${file%.test} =========="; ./$$file; echo ""; done > results.txt

clean:
	rm -f *.o *.test *.a results.txt

realclean: clean
	rm -rf *-src

# MAYO Tests
MAYO_TESTS=mayo_1.test mayo_2.test mayo_3.test mayo_5.test

mayo-src:
	git clone https://github.com/PQCMayo/MAYO-C mayo-src

mayo-src/build/src/libmayo_common_sys.a: mayo-src
	cd mayo-src && mkdir -p build && cd build && cmake -DENABLE_STRICT=OFF .. && make -j

mayo_%.o: mayo-src test.c
	$(CC) -c $(CFLAGS) -Imayo-src/src/mayo_$*/ -o $@ test.c

mayo_%.test: mayo_%.o benchmark.o mayo-src/build/src/libmayo_common_sys.a
	$(CC) -Lmayo-src/build/src -o $@ mayo_$*.o benchmark.o -lmayo_$*_nistapi -lmayo_$* -lmayo_common_sys

mayo: $(MAYO_TESTS)

# PQOV Tests
PQOV_TESTS = $(shell echo pqov_{Ip,III,Is,V}{,_pkc,_pkc_skc}.test)
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
FALCON_TESTS= $(shell echo falcon{512,1024}.test)

falcon-src:
	wget https://falcon-sign.info/falcon-round3.zip
	unzip falcon-round3.zip
	rm falcon-round3.zip
	mv falcon-round3 falcon-src

libfalcon%.a: falcon-src
	make -C falcon-src/Optimized_Implementation/falcon$*/falcon$*avx2 -j
	rm falcon-src/Optimized_Implementation/falcon$*/falcon$*avx2/build/PQCgenKAT_sign.o
	ar -crs libfalcon$*.a falcon-src/Optimized_Implementation/falcon$*/falcon$*avx2/build/*.o

falcon%.o: falcon-src test.c
	$(CC) -c $(CFLAGS) -Ifalcon-src/Optimized_Implementation/falcon$*/falcon$*avx2 -o $@ test.c

falcon%.test: falcon%.o benchmark.o libfalcon%.a
	$(CC) -L. falcon$*.o benchmark.o -lfalcon$* -o $@

falcon: $(FALCON_TESTS)

# CROSS
CROSS=cross-src/Reference_Implementation
CROSS_TESTS = $(shell echo cross_{RSDP,RSDPG}-{SIG_SIZE,BALANCED,SPEED}-CATEGORY_{1,3,5}.test)

cross-src:
	wget https://www.cross-crypto.com/CROSS_submission_package_v1.2.zip
	unzip CROSS_submission_package_v1.2.zip
	mv CROSS_submission_package_v1.2 cross-src
	rm CROSS_submission_package_v1.2.zip
	cp cross-src/Optimized_Implementation/lib/CROSS.c cross-src/Reference_Implementation/lib/CROSS.c
	cp cross-src/Optimized_Implementation/include/* cross-src/Reference_Implementation/include

libcross_%.a: cross-src
	for file in $(CROSS)/lib/*.c; do \
		$(CC) -c -I$(CROSS)/include -march=native -O3 -g3 $(call GET_FLAGS, $*) -o $${file%.c}_$*.o $${file};\
	done
	ar -crs libcross_$*.a $(CROSS)/lib/*_$*.o

cross_%.o: cross-src test.c
	$(CC) -c $(CFLAGS) -I$(CROSS)/include $(call GET_FLAGS, $*) -o $@ test.c

cross_%.test: cross_%.o benchmark.o libcross_%.a
	$(CC) -L. cross_$*.o benchmark.o -lcross_$* -o $@

cross: $(CROSS_TESTS)

# LESS
LESS=less-src/Optimized_Implementation/avx2
LESS_TESTS = $(shell echo less_{SHORT_SIG,BALANCED}-CATEGORY_{1,3,5}.test)
LESS_CFLAGS = -O3 -DNDEBUG -fpermissive -march=native -mavx2 -mavx -ftree-vectorize -funroll-loops -fomit-frame-pointer -fno-stack-protector

less-src:
	git clone https://github.com/less-sig/LESS less-src

libless_%.a: less-src
	for file in $(LESS)/lib/*.c; do \
		$(CC) -c -I$(LESS)/include $(LESS_CFLAGS) $(call GET_FLAGS, $*) -o $${file%.c}_$*.o $${file};\
	done
	ar -crs libless_$*.a $(LESS)/lib/*_$*.o

less_%.o: less-src test.c
	$(CC) -c $(CFLAGS) -I$(LESS)/include $(call GET_FLAGS, $*) -o $@ test.c

less_%.test: less_%.o benchmark.o libless_%.a
	$(CC) -L. less_$*.o benchmark.o -lless_$* -o $@

less: $(LESS_TESTS)

# MEDS
MEDS=meds-src/Optimized_Implementation
MEDS_TESTS= $(shell echo meds{9923,13220,41711,55604,134180,167717}.test)

meds-src:
	wget https://www.meds-pqc.org/pack/MEDS-2023-07-26.tgz
	tar xf MEDS-2023-07-26.tgz
	mv MEDS-2023-07-26 meds-src
	rm MEDS-2023-07-26.tgz

libmeds%.a: meds-src
	make -C $(MEDS)/MEDS$* -j
	ar -crs libmeds$*.a $(MEDS)/MEDS$*/build/*.o

meds%.o: meds-src test.c
	$(CC) -c $(CFLAGS) -I$(MEDS)/MEDS$* -o $@ test.c

meds%.test: meds%.o benchmark.o libmeds%.a
	$(CC) -L. meds$*.o benchmark.o -lmeds$* -lssl -lcrypto -o $@

meds: $(MEDS_TESTS)