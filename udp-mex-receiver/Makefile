# Author: Dan O'Shea dan@djoshea.com 2012
# Modified for nd_lab: Alexey Yu. Illarionov, INI UZH Zurich, <ayuillarionov@ini.uzh.ch> (C) 2019

# to get the options in this file, run in Matlab:
# mex('-v', '-f', [matlabroot '/bin/matopts.sh'], '-lrt', 'signalLogger.cc', 'writer.cc', 'buffer.cc', 'signal.cc')

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

	CC = gcc

	# grab the newest version of matlab (well, the last modified directory in /usr/local/MATLAB)
	MATLAB_BIN = $(shell ls -t /usr/local/MATLAB/*/bin/matlab | head -1)
	MATLAB_ROOT = $(abspath $(dir $(MATLAB_BIN))../)
	MATLAB_ARCH = glnxa64

	ECHO = @echo -n "$(COLOR_BLUE)==>$(COLOR_WHITE)"
	ECHO_END = ;echo " $(COLOR_BLUE)<==$(COLOR_NONE)"

	CFLAGS_OS = -DLINUX

	LDFLAGS_OS += -Wl,--no-undefined
	LDFLAGS_OS += -Wl,--version-script,$(MATLAB_ROOT)/extern/lib/$(MATLAB_ARCH)/mexFunction.map
	# changed rpath-link to rpath to solve dynamic loading issue with libmat.so
	LDFLAGS_OS += -lrt -Wl,-rpath,$(MATLAB_ROOT)/bin/$(MATLAB_ARCH)
endif
# --- MAC OS
ifeq ($(SYSTEM), Darwin)
	OS = mac

	CC = clang

	MATLAB_ROOT=/Applications/MATLAB_R2019a.app
	MATLAB_ARCH = maci64

	ECHO = @echo
	ECHO_END = 

	CFLAGS_OS = -DMACOS -I/usr/local/include/

	LDFLAGS_OS = -Wl,-undefined,error
	# changed rpath-link to rpath to solve dynamic loading issue with libmat.so
	LDFLAGS_OS += -Wl,-rpath,$(MATLAB_ROOT)/bin/$(MATLAB_ARCH) -L/usr/local/lib/ -largp
endif

# compiler options
GDBFLAGS = -ggdb3 -DDEBUG
OPTFLAG = -O3
CFLAGS = -Wall -Wno-comments -pedantic $(CFLAGS_OS) -std=c99
CFLAGS += -DMATLAB_MEX_FILE
CFLAGS_MEX = -I$(MATLAB_ROOT)/extern/include -I$(MATLAB_ROOT)/simulink/include -D_GNU_SOURCE -I$(MATLAB_ROOT)/extern/include/cpp -DGLNXA64 -DGCC -DMX_COMPAT_32
CFLAGS_MEX += $(OPTFLAG) -DNDEBUG
CFLAGS_MEX += -fexceptions -fPIC -fno-omit-frame-pointer
LDFLAGS = $(LDFLAGS_OS) -lpthread
LDFLAGS_MEX = -L$(MATLAB_ROOT)/bin/$(MATLAB_ARCH) -lmat -lmex -lmx -lm -lstdc++ -shared -pthread

# linker options
LD = $(CC)

# where to locate output files
BUILD_DIR = build
BUILD_DIR_EXTERN = build/extern
BIN_DIR =

# lists of h, cc, and o files
SERIALIZER_SRC_DIR = ../trialLogger/src
SERIALIZER_SRC_FILES = writer network parser trie signal utils

H_FILES_EXTERN = $(addprefix $(SERIALIZER_SRC_DIR)/, $(addsuffix .h, $(SERIALIZER_SRC_FILES)))
C_FILES_EXTERN = $(addprefix $(SERIALIZER_SRC_DIR)/, $(addsuffix .c, $(SERIALIZER_SRC_FILES)))
PCH_FILES_EXTERN = $(addprefix $(BUILD_DIR_EXTERN)/, $(addsuffix .pch, $(SERIALIZER_SRC_FILES)))
O_FILES_EXTERN = $(addprefix $(BUILD_DIR_EXTERN)/, $(addsuffix .o, $(SERIALIZER_SRC_FILES)))
GDBO_FILES_EXTERN = $(addprefix $(BUILD_DIR_EXTERN)/, $(addsuffix .gdb.o, $(SERIALIZER_SRC_FILES)))

C_FILES = udpMexReceiver.c
O_FILES = $(BUILD_DIR)/udpMexReceiver.o
GDBO_FILES = $(BUILD_DIR)/udpMexReceiver.gdb.o

# final output
MEX_FILE = udpMexReceiver.mexa64
GDB_MEX_FILE = udpMexReceiver_gdb.mexa64

# debugging, use make print-VARNAME to see value
print-%:
	@echo '$* = $($*)'

.PHONY: strip clobber clean depend all

############ TARGETS #####################
all: $(MEX_FILE) $(GDB_MEX_FILE)

.PRECIOUS: $(PCH_FILES) $(PCH_FILES_EXTERN)

$(BUILD_DIR_EXTERN)/%.pch: $(SERIALIZER_SRC_DIR)/%.h $(H_FILES_EXTERN) | $(BUILD_DIR_EXTERN)
	$(ECHO) "Precompiling header $<" $(ECHO_END)
	$(CC) -c $(CFLAGS) $(CFLAGS_MEX) $(GDBFLAGS) -x c-header -o $@ $<

# compile .o for each .c, depends also on all .h files
$(BUILD_DIR_EXTERN)/%.o: $(SERIALIZER_SRC_DIR)/%.c $(H_FILES_EXTERN) | $(BUILD_DIR_EXTERN)
	$(ECHO) "Extern Compiling $<" $(ECHO_END)
	$(CC) -c $(CFLAGS) $(CFLAGS_MEX) -o $@ $< 

$(BUILD_DIR)/%.o: $(C_FILES) $(H_FILES_EXTERN) | $(BUILD_DIR)
	$(ECHO) "Compiling $<" $(ECHO_END)
	$(CC) -c $(CFLAGS) $(CFLAGS_MEX) -o $@ $< 

# compile .dbg.o for each .c, depends also on all .h files
$(BUILD_DIR_EXTERN)/%.gdb.o: $(SERIALIZER_SRC_DIR)/%.c $(H_FILES_EXTERN) | $(BUILD_DIR_EXTERN)
	$(ECHO) "GDB Extern Compiling $<" $(ECHO_END)
	$(CC) -c $(GDBFLAGS) $(CFLAGS) $(CFLAGS_MEX) -o $@ $< 

$(BUILD_DIR)/%.gdb.o: $(C_FILES) $(H_FILES_EXTERN) | $(BUILD_DIR)
	$(ECHO) "GDB Compiling $<" $(ECHO_END)
	$(CC) -c $(GDBFLAGS) $(CFLAGS) $(CFLAGS_MEX) -o $@ $< 

# link *.o into executable
$(MEX_FILE): $(O_FILES) $(O_FILES_EXTERN) | $(BIN_DIR)
	$(ECHO) "Linking $@" $(ECHO_END)
	$(LD) $(OPTFLAG) -o $@ $(O_FILES) $(O_FILES_EXTERN) $(LDFLAGS) $(LDFLAGS_MEX)
	strip $@
	$(ECHO) "Built $@ successfully!" $(ECHO_END)

$(GDB_MEX_FILE): $(GDBO_FILES) $(GDBO_FILES_EXTERN) | $(BIN_DIR)
	$(ECHO) "GDB Linking $@" $(ECHO_END)
	$(LD) $(OPTFLAG) $(GDBFLAGS) -o $@ $(O_FILES) $(GDBO_FILES_EXTERN) $(LDFLAGS) $(LDFLAGS_MEX)
	$(ECHO) "GDB Built $@ successfully!" $(ECHO_END)
	
$(BUILD_DIR):
	@mkdir -p $@
	
$(BUILD_DIR_EXTERN):
	@mkdir -p $@

# generate an index (or tag) file of names found in source and header files
ctags:
	ctags --c-kinds=+px --fields=+aiS --extra=+q $(C_FILES) $(C_FILES_EXTERN) $(H_FILES_EXTERN)

strip:
	strip $(EXE)

# clean and delete executable
clobber: clean
	@rm -f $(MEX_FILE) $(GDB_MEX_FILE)

# delete .o files and garbage
clean: 
	$(ECHO) "Cleaning build" $(ECHO_END)
	@rm -rf $(BUILD_DIR) $(BUILD_DIR_EXTERN) *~ core 

depend:
	makedepend $(C_FILES) $(C_FILES_EXTERN)
