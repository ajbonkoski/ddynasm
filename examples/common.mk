ROOT := $(subst /examples/common.mk,,$(realpath $(lastword $(MAKEFILE_LIST))))

DC = dmd
DFLAGS = -O

DEP = $(ROOT)/import/ddynasm/dasm_x86.d $(ROOT)/lib/ddynasm.a
DDYNASM = $(ROOT)/bin/ddynasm

ALL = $(BIN)
all: $(ALL)
	rm -f $(CLEAN) dasm_x86.o

$(SRC): $(DASD)
	$(DDYNASM) $^ > $@

$(BIN): $(SRC) $(DEP)
	$(DC) $(DFLAGS) $^

clean:
	rm -f $(ALL) $(CLEAN) *.o
