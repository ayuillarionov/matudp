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

	ECHO = @echo -n "$(COLOR_BLUE)==>$(COLOR_WHITE)"
	ECHO_END = ;echo " $(COLOR_BLUE)<==$(COLOR_NONE)"

	CFLAGS_OS = -DLINUX

	# grab the newest version of matlab (well, the last modified directory in /usr/local/MATLAB)
	MATLAB_BIN = $(shell ls -t /usr/local/MATLAB/*/bin/matlab | head -1)
	MATLAB_ROOT = $(abspath $(dir $(MATLAB_BIN))../)

	MATLAB_ARCH = glnxa64

	# changed rpath-link to rpath to solve dynamic loading issue with libmat.so
	LDFLAGS_OS = -lrt -Wl,-rpath,$(MATLAB_ROOT)/bin/$(MATLAB_ARCH)
endif
# --- MAC OS
ifeq ($(SYSTEM), Darwin)
	OS = mac

	CC = clang

	ECHO = @echo
	ECHO_END = 

	CFLAGS_OS = -DMACOS -I/usr/local/include/
	# changed rpath-link to rpath to solve dynamic loading issue with libmat.so
	LDFLAGS_OS = -Wl,-rpath,$(MATLAB_ROOT)/bin/$(MATLAB_ARCH) -L/usr/local/lib/ -largp

	MATLAB_ROOT=/Applications/MATLAB_R2019a.app
	MATLAB_ARCH = maci64
endif

# compiler options
GDBFLAGS = -ggdb3 -DDEBUG
OPTFLAG = -O3
CFLAGS = -Wall -Wno-comments -pedantic $(CFLAGS_OS) -std=c99
CFLAGS_MEX = -I$(MATLAB_ROOT)/extern/include -I$(MATLAB_ROOT)/simulink/include -D_GNU_SOURCE -I$(MATLAB_ROOT)/extern/include/cpp -DGLNXA64 -DGCC -DMX_COMPAT_32 $(OPTFLAG) -DNDEBUG
LDFLAGS = $(LDFLAGS_OS) -lpthread
LDFLAGS_MEX = -L$(MATLAB_ROOT)/bin/$(MATLAB_ARCH) -lmat -lmx -lm 

#-DMATLAB_MEX_FILE 

# linker options
LD = $(CC)

# where to locate output files
SRC_DIR = src
BUILD_DIR = build
BIN_DIR = bin

# lists of h, cc, and o files
H_FILES = $(wildcard $(SRC_DIR)/*.h)
PCH_FILES = $(patsubst $(SRC_DIR)/%.h, $(BUILD_DIR)/%.pch, $(H_FILES))
C_FILES = $(wildcard $(SRC_DIR)/*.c)
O_FILES = $(patsubst $(SRC_DIR)/%.c, $(BUILD_DIR)/%.o, $(C_FILES))
GDBO_FILES = $(patsubst $(SRC_DIR)/%.c, $(BUILD_DIR)/%.dbg.o, $(C_FILES))

# final output
EXE = $(BIN_DIR)/trialLogger-$(OS)
GDBEXE = $(BIN_DIR)/trialLogger-$(OS)-debug

# debugging, use make print-VARNAME to see value
print-%:
	@echo '$* = $($*)'

.PHONY: strip clobber clean depend all

############ TARGETS #####################
all: $(EXE) $(GDBEXE)

.PRECIOUS: $(PCH_FILES)

$(BUILD_DIR)/%.pch: $(SRC_DIR)/%.h $(H_FILES) | $(BUILD_DIR)
	$(ECHO) "Precompiling header $<" $(ECHO_END)
	$(CC) $(CFLAGS) $(CFLAGS_MEX) $(GDBFLAGS) -c -x c-header -o $@ $<

# compile .o for each .c, depends also on all .h files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c $(PCH_FILES) | $(BUILD_DIR)
	$(ECHO) "Compiling $<" $(ECHO_END)
	$(CC) $(CFLAGS) $(CFLAGS_MEX) -c -o $@ $< 

# compile .dbg.o for each .c, depends also on all .h files
$(BUILD_DIR)/%.dbg.o: $(SRC_DIR)/%.c $(PCH_FILES) | $(BUILD_DIR)
	$(ECHO) "GDB Compiling $<" $(ECHO_END)
	$(CC) $(GDBFLAGS) $(CFLAGS) $(CFLAGS_MEX) -c -o $@ $< 

# link *.o into executable
$(EXE): $(O_FILES) | $(BIN_DIR)
	$(ECHO) "Linking $@" $(ECHO_END)
	$(LD) $(OPTFLAG) -o $@ $(O_FILES) $(LDFLAGS) $(LDFLAGS_MEX)
	strip $@
	$(ECHO) "Built $@ successfully!" $(ECHO_END)

$(GDBEXE): $(GDBO_FILES) | $(BIN_DIR)
	$(ECHO) "GDB Linking $@" $(ECHO_END)
	$(LD) $(OPTFLAG) $(GDBFLAGS) -o $@ $(O_FILES) $(LDFLAGS) $(LDFLAGS_MEX)
	$(ECHO) "Built $@ successfully!" $(ECHO_END)
	
$(BUILD_DIR):
	@mkdir -p $@
	
$(BIN_DIR):
	@mkdir -p $@

# generate an index (or tag) file of names found in source and header files
ctags:
	ctags --c-kinds=+px --fields=+aiS --extra=+q $(H_FILES) $(C_FILES)

strip:
	strip $(EXE)

# clean and delete executable
clobber: clean
	@rm -f $(EXE) $(GDBEXE)

# delete .o files and garbage
clean: 
	$(ECHO) "Cleaning build" $(ECHO_END)
	@rm -rf $(PCH_FILES) $(O_FILES) $(BUILD_DIR) *~ core 

depend:
	makedepend $(C_FILES)
