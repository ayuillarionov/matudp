# Author    : Alexey Yu. Illarionov, INI UZH Zurich (C) 2019
#             <ayuillarionov@ini.uzh.ch>

# pretty print utils
ifeq ($(COLOR), off)
	COLOR_NONE=
	COLOR_WHITE=
	COLOR_BLUE=
else
	COLOR_NONE=\33[0m
	COLOR_WHITE=\33[37;01m
	COLOR_BLUE=\33[34;01m
endif

# platform
SYSTEM = $(shell echo `uname -s`)

# --- LINUX
ifeq ($(SYSTEM), Linux)
	OS = lin

	ECHO = @echo -n "$(COLOR_BLUE)==>$(COLOR_WHITE)"
	ECHO_END = ;echo " $(COLOR_BLUE)<==$(COLOR_NONE)"
	CFLAGS_OS = -DLINUX
	LDFLAGS_OS = 
endif
# --- MAC OS
ifeq ($(SYSTEM), Darwin)
	OS = mac

	ECHO = @echo
	ECHO_END = 
	CFLAGS_OS = -DMACOS -I/usr/local/include/
	LDFLAGS_OS = -L/usr/local/lib/ -largp
endif

# compiler options
CC = gcc
#CC = clang
CWFLAGS = -Wall -Wsign-compare -Wwrite-strings -Wtype-limits
#CWFLAGS = -Wall -Wsign-compare -Wwrite-strings -Wtype-limits -Werror
OPTFLAG = -O3
CFLAGS = -std=gnu99 -pedantic $(CWFLAGS) $(CFLAGS_OS)
GDBFLAGS = -ggdb3 -DDEBUG
LDFLAGS = $(LDFLAGS_OS)

# linker options
LD = $(CC)

# files locations
SRC_DIR = src
BUILD_DIR = build
BIN_DIR = bin

# lists of .h, .c and .o files
HEADS = $(wildcard $(SRC_DIR)/*.h)
PCHS = $(patsubst $(SRC_DIR)/%.h, $(BUILD_DIR)/%.pch, $(HEADS))
SRCS = $(wildcard $(SRC_DIR)/*.c)
OBJS = $(patsubst $(SRC_DIR)/%.c, $(BUILD_DIR)/%.o, $(SRCS))
GDBOBJS = $(patsubst $(SRC_DIR)/%.c, $(BUILD_DIR)/%.dbg.o, $(SRCS))

# final output
EXE = $(BIN_DIR)/arduino-FDC-loop
GDBEXE = $(BIN_DIR)/arduino-FDC-loop-debug

# debugging, use make print-VARNAME to see value
print-%:
	@echo '$*=$($*)'

.PHONY: strip clobber clean depend all

###### TARGETS ######
all: $(EXE) $(GDBEXE)

.PRECIOUS: $(PCHS)

$(BUILD_DIR)/%.pch: $(SRC_DIR)/%.h $(HEADS) | $(BUILD_DIR)
	$(ECHO) "Precompiling header $<" $(ECHO_END)
	$(CC) $(CFLAGS) $(GDBFLAGS) -c -x c-header -o $@ $<

# compile .o for each .c, depends also on all .h files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c $(PCHS) | $(BUILD_DIR)
	$(ECHO) "Compiling $<" $(ECHO_END)
	$(CC) $(OPTFLAG) $(CFLAGS) -c -o $@ $<

# compile dbg.o for each .c, depends also on all .h files
$(BUILD_DIR)/%.dbg.o: $(SRC_DIR)/%.c $(PCHS) | $(BUILD_DIR)
	$(ECHO) "GDB Compiling $<" $(ECHO_END)
	$(CC) $(CFLAGS) $(GDBFLAGS) -c -o $@ $<

# link *.o into executable
$(EXE): $(OBJS) | $(BIN_DIR)
	$(ECHO) "Linking $@" $(ECHO_END)
	$(LD) $(OPTFLAG) $(CFLAGS) $(LDFLAGS) $(OBJS) -o $@ -lm
	strip $@
	$(ECHO) "Built $@ successfully!" $(ECHO_END)

$(GDBEXE): $(GDBOBJS) | $(BIN_DIR)
	$(ECHO) "GDB Linking $@" $(ECHO_END)
	$(LD) $(CFLAGS) $(GDBFLAGS) $(LDFLAGS) $(GDBOBJS) -o $@ -lm
	$(ECHO) "Built $@ successfully!" $(ECHO_END)

$(BUILD_DIR):
	@mkdir -p $@

$(BIN_DIR):
	@mkdir -p $@

# generate an index (or tag) file of names found in source and header files
ctags:
	ctags --c-kinds=+px --fields=+aiS --extra=+q $(HEADS) $(SRCS)

# removes inessential information from executable
strip:
	strip $(EXE)

# clean and delete executable
clobber: clean
	@rm -f $(EXE) $(GDBEXE)

# delete .o files and garbage
clean:
	$(ECHO) "Cleaning build" $(ECHO_END)
	@rm -rf $(PCHS) $(OBJS) $(BUILD_DIR) *~ core

depend:
	makedepend $(SRCS)
	#makedepend -a -o .dbg.o $(SRCS)
