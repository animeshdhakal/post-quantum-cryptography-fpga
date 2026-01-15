import os
import ctypes
import sys
import time
import random

# Load the shared library
lib_path = os.path.abspath("obj_dir/libkyber_sim.so")
sim = ctypes.CDLL(lib_path)

# Define register offsets (must match kyber_top.sv)
REG_STATUS = 0x00
REG_START = 0x20
REG_MEM_ADDR = 0x08
REG_MEM_WDATA = 0x0C
REG_MEM_RDATA = 0x10
REG_MEM_WE = 0x14

# Define simulation functions
sim.sim_init.argtypes = []
sim.sim_init.restype = ctypes.c_void_p

sim.sim_step.argtypes = [ctypes.c_int]
sim.sim_step.restype = None

sim.sim_write.argtypes = [ctypes.c_int, ctypes.c_int]
sim.sim_write.restype = None

sim.sim_read.argtypes = [ctypes.c_int]
sim.sim_read.restype = ctypes.c_int

sim.sim_close.argtypes = []
sim.sim_close.restype = None

# Kyber Constants
Q = 3329
ROOT_OF_UNITY = 17


def bit_reverse(n, bits):
    result = 0
    for _ in range(bits):
        result = (result << 1) | (n & 1)
        n >>= 1
    return result


def hw_mul(a, b):  # inputs signed 16-bit
    if a > 32767:
        a -= 65536
    if b > 32767:
        b -= 65536

    prod = a * b
    m = (prod * -3327) & 0xFFFF
    if m > 32767:
        m -= 65536

    mq = m * Q
    t = (prod - mq) >> 16

    if t >= Q:
        t -= Q
    elif t < 0:
        t += Q

    return t & 0xFFFF


def hw_add_sub(a, b, t):
    raw_sum = a + t
    if raw_sum >= Q:
        sum_val = raw_sum - Q
    else:
        sum_val = raw_sum
    if a >= t:
        diff_val = a - t
    else:
        diff_val = (a + Q) - t
    return sum_val, diff_val


def mod_inverse(a):
    m = Q
    y = 0
    x = 1
    if m == 1:
        return 0
    while a > 1:
        q_div = a // m
        t = m
        m = a % m
        a = t
        t = y
        y = x - q_div * y
        x = t
    if x < 0:
        x += Q
    return x


def reference_ntt(poly):
    zetas = [0] * 128
    val = 1
    mont_r = (1 << 16) % Q
    for i in range(128):
        zetas[bit_reverse(i, 7)] = (val * mont_r) % Q
        val = (val * ROOT_OF_UNITY) % Q

    res = list(poly)
    k = 1
    length = 128
    while length >= 2:
        start = 0
        while start < 256:
            zeta = zetas[k]
            k += 1
            for j in range(start, start + length):
                t = hw_mul(res[j + length], zeta)
                u = res[j]
                res[j], res[j + length] = hw_add_sub(u, res[j + length], t)
            start += 2 * length
        length //= 2
    return res


def reference_inv_ntt(poly):
    # Corrected INTT Logic
    zetas = [0] * 128
    val = 1
    mont_r = (1 << 16) % Q
    for i in range(128):
        zetas[bit_reverse(i, 7)] = (val * mont_r) % Q
        val = (val * ROOT_OF_UNITY) % Q

    zetas_inv_table = []
    r2 = (mont_r * mont_r) % Q
    for z in zetas:
        inv = mod_inverse(z)
        target = (inv * r2) % Q
        zetas_inv_table.append(target)

    res = list(poly)
    # Loop len 2..128
    length = 2
    while length <= 128:
        start = 0
        k = 128 // length  # Corrected starting K

        while start < 256:
            zeta = zetas_inv_table[k]
            k += 1

            for j in range(start, start + length):
                sum_val, diff_val = hw_add_sub(res[j], 0, res[j + length])
                res[j] = sum_val
                res[j + length] = hw_mul(diff_val, zeta)
            start += 2 * length
        length *= 2

    # Scale
    inv_128 = mod_inverse(128)
    inv_128_mont = (inv_128 * mont_r) % Q
    for i in range(256):
        res[i] = hw_mul(res[i], inv_128_mont)

    return res


def test_inv_ntt_ref():
    print("Testing INTT Logic in Python...")
    random.seed(123)
    poly = [random.randint(0, Q - 1) for _ in range(256)]
    fwd = reference_ntt(poly)
    inv = reference_inv_ntt(fwd)
    mismatches = 0
    for i in range(256):
        if inv[i] != poly[i]:
            mismatches += 1
    if mismatches == 0:
        print("Python Ref INTT Verified!")
    else:
        print(f"Python Ref INTT FAILED: {mismatches} mismatches")


def test_ntt_hw():
    print("=== Testing Hardware Forward NTT ===")
    input_poly = []
    random.seed(42)
    MEM_BASE = 0x1000

    print("Loading Memory...")
    for i in range(256):
        val = random.randint(0, Q - 1)
        sim.sim_write(MEM_BASE + (i * 4), val)
        input_poly.append(val)

    # Assert Start=1, Mode=0 (NTT)
    # 0x01 = Start
    sim.sim_write(REG_START, 1)
    sim.sim_step(1)
    sim.sim_write(REG_START, 0)

    # Wait for Done
    t = 0
    while True:
        status = sim.sim_read(REG_STATUS)
        if not (status & 0x02):  # Busy bit 1
            if t > 0:
                break
        sim.sim_step(1)
        t += 1
        if t > 5000:
            print("Timeout")
            break

    # Read
    hw_out = []
    for i in range(256):
        val = sim.sim_read(MEM_BASE + (i * 4))
        hw_out.append(val)

    ref_poly = reference_ntt(input_poly)
    mismatches = 0
    for i in range(256):
        if hw_out[i] != ref_poly[i]:
            mismatches += 1
            if mismatches < 5:
                print(f"NTT Mismatch {i}: HW {hw_out[i]} != Ref {ref_poly[i]}")

    if mismatches == 0:
        print("Hardware NTT SUCCESS")
    else:
        print(f"Hardware NTT FAILURE: {mismatches} mismatches")


def test_inv_ntt_hw():
    print("=== Testing Hardware Inverse NTT ===")
    input_poly = []
    random.seed(99)
    MEM_BASE = 0x1000

    # We want to test InvNTT.
    # We can pass Random data, and compare with Ref_InvNTT(Random).

    print("Loading Memory...")
    for i in range(256):
        val = random.randint(0, Q - 1)
        sim.sim_write(MEM_BASE + (i * 4), val)
        input_poly.append(val)

    # Assert Start=1, Mode=1 (INTT)
    # Bit 0 = Start, Bit 1 = Mode.
    # 3 = 11b.
    sim.sim_write(REG_START, 3)
    sim.sim_step(1)
    sim.sim_write(REG_START, 2)  # Start=0, Mode=1 (Keep mode hold? Or latched?)

    t = 0
    while True:
        status = sim.sim_read(REG_STATUS)
        if not (status & 0x02):
            if t > 0:
                break
        sim.sim_step(1)
        t += 1
        if t > 10000:
            print("Timeout INTT")
            break

    print(f"INTT Done after {t} cycles")

    hw_out = []
    for i in range(256):
        val = sim.sim_read(MEM_BASE + (i * 4))
        hw_out.append(val)

    ref_poly = reference_inv_ntt(input_poly)

    mismatches = 0
    for i in range(256):
        if hw_out[i] != ref_poly[i]:
            mismatches += 1
            if mismatches < 5:
                print(f"INTT Mismatch {i}: HW {hw_out[i]} != Ref {ref_poly[i]}")

    if mismatches == 0:
        print("Hardware INTT SUCCESS")
    else:
        print(f"Hardware INTT FAILURE: {mismatches} mismatches")


if __name__ == "__main__":
    test_inv_ntt_ref()
    sim.sim_init()
    test_ntt_hw()
    test_inv_ntt_hw()
    sim.sim_close()
