import ctypes
import os
import time

# Load Library
paths = [
    "libkyber_sim.so",
    "obj_dir/libkyber_sim.so",
    "sim/verilator/libkyber_sim.so",
    "sim/verilator/obj_dir/libkyber_sim.so",
]
LIB_PATH = None
for p in paths:
    if os.path.exists(p):
        LIB_PATH = os.path.abspath(p)
        break

if not LIB_PATH:
    print("Error: Could not find libkyber_sim.so")
    exit(1)

lib = ctypes.CDLL(LIB_PATH)

lib.sim_init.restype = None
lib.sim_write.argtypes = [ctypes.c_uint32, ctypes.c_uint32]
lib.sim_read.argtypes = [ctypes.c_uint32]
lib.sim_read.restype = ctypes.c_uint32
lib.sim_step.argtypes = [ctypes.c_int]

# Absorb Seed Bind
try:
    lib.absorb_seed.argtypes = [ctypes.POINTER(ctypes.c_uint32), ctypes.c_int]
    lib.absorb_seed.restype = None
    HAS_ABSORB = True
except AttributeError:
    HAS_ABSORB = False
    print("WARNING: absorb_seed not found!")

lib.sim_init()


def write(addr, val):
    lib.sim_write(addr, val)


def read(addr):
    return lib.sim_read(addr)


def step(n):
    lib.sim_step(n)


print("Starting Sponge Isolation Test...")

# 0. Test Register R/W
print("Testing Register R/W (Rate)...")
write(0x0010, 0x1F)  # Write 31
val = read(0x0010)
print(f"Read Back Rate: {hex(val)}")
if val != 0x1F:
    print("ERROR: Register R/W Failed!")
else:
    print("Register R/W OK.")

# 1. Absorb Seed
seed_val = 0x12345678
print(f"Absorbing Seed: {hex(seed_val)}...")

if HAS_ABSORB:
    arr = (ctypes.c_uint32 * 1)(seed_val)
    lib.absorb_seed(arr, 1)
else:
    # Manual
    write(0x0004, 2)  # Last
    write(0x0014, seed_val)  # Go

step(50)  # Wait for sponge (24 rounds)

# 2. Check Input Status
status = read(0x0000)
print(f"Status Register: {bin(status)}")
# Bit 0: Busy, Bit 1: CoreBusy, Bit 2: AbsorbReady?, Bit 3: SqueezeValid?
# RTL says: {28'd0, sponge_squeeze_valid, sponge_absorb_read, core_busy, sponge_busy}
# Bit 0: sponge_busy
# Bit 1: core_busy
# Bit 2: absorb_ready (sponge_absorb_read)
# Bit 3: squeeze_valid (sponge_squeeze_valid)

# 3. Read Squeeze Data
# Addr 0x0014 reads squeeze data [31:0] and optionally triggers next squeeze per byte?
# RTL:
# if (bus_read 0x0014) -> data = squeeze_data[31:0]. If valid -> squeeze_go <= 1.
# This means reading triggers "Advance".

print("Reading Squeeze Data...")
for i in range(10):
    val = read(0x0014)
    print(f"Word {i}: {hex(val)}")
    # Reading should trigger squeeze_go, advancing the sponge or word index?
    # keccak_sponge increments word_idx or permutes.
    step(2)

lib.sim_close()
print("Test Done")
