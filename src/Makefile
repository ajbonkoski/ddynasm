DC = dmd
DFLAGS = -O -release -inline -noboundscheck

CC = gcc
CFLAGS = -O3

DDYNASM = ../bin/ddynasm
DDYNASM_OBJ = ddynasm.o
DDYNASM_SRC = ddynasm.d

DDYNASM_CLIB_OBJ = dynasm_lib.o
DDYNASM_CLIB = ../lib/ddynasm.a

DDYNASM_IMPORT_SRC = dasm_x86.d
DDYNASM_IMPORT = ../import/ddynasm/dasm_x86.d

ALL = $(DDYNASM) $(DDYNASM_CLIB) $(DDYNASM_IMPORT)
all: $(ALL)
	rm -f *.o

$(DDYNASM): $(DDYNASM_OBJ)
	$(DC) $(DFLAGS) $^ -of$@

$(DDYNASM_CLIB): $(DDYNASM_CLIB_OBJ)
	ar rc $@ $(DDYNASM_CLIB_OBJ)

$(DDYNASM_IMPORT): $(DDYNASM_IMPORT_SRC)
	cp $^ $@

%.o: %.d
	$(DC) $(DFLAGS) -c $<

%.o: %.c
	$(CC) $(CFLAGS) -c $<

clean:
	rm -f *.o $(ALL)
