# Makefile for Verilator Simulation Shared Library

# Paths
RTL_DIR = ../../rtl
TOP_MODULE = kyber_top
CPP_WRAPPER = sim_main.cpp
BUILD_DIR = obj_dir
LIB_NAME = libkyber_sim.so

# Verilator configuration
VERILATOR = verilator
VERILATOR_FLAGS = --cc --exe --build -O3 --top-module $(TOP_MODULE) \
				  -I$(RTL_DIR)/top -I$(RTL_DIR)/core -I$(RTL_DIR)/primitives -I$(RTL_DIR)/primitives/keccak \
				  -CFLAGS "-fPIC" -LDFLAGS "-shared"

# Source files
SV_SOURCES = $(RTL_DIR)/top/$(TOP_MODULE).sv

.PHONY: all clean

all: $(LIB_NAME)

$(LIB_NAME): $(SV_SOURCES) $(CPP_WRAPPER)
	@echo "Building Verilator model..."
	$(VERILATOR) $(VERILATOR_FLAGS) $(SV_SOURCES) $(CPP_WRAPPER) -o $(LIB_NAME)
	@echo "Build complete: $(LIB_NAME)"

clean:
	rm -rf $(BUILD_DIR) $(LIB_NAME)
