import ctypes
import os
import time
import random


def bit_reverse(n, bits=8):
    return int("{:0{width}b}".format(n, width=bits)[::-1], 2)


class KyberNTT:
    q = 3329
    n = 256
    # Primitive root of unity: 17
    root = 17

    def __init__(self):
        # Precompute powers
        self.zetas = [1] * self.n
        for i in range(1, self.n):
            self.zetas[i] = (self.zetas[i - 1] * self.root) % self.q

    def ntt(self, poly):
        # Standard iterative NTT (BitReversed Input -> Standard Output for checking)
        # Actually Kyber HW uses Standard -> BitReversed+Montgomery?
        # Let's implementation simple DFT for correctness check first
        res = [0] * self.n
        for k in range(self.n):
            sum_val = 0
            w_k = 1
            # w^k
            w_step = pow(self.root, bit_reverse(k), self.q)  # if bitreversed?
            # Standard DFT: sum x[i] * w^(ik)
            w = pow(self.root, k, self.q)
            for i in range(self.n):
                term = (poly[i] * pow(w, i, self.q)) % self.q
                sum_val = (sum_val + term) % self.q
            res[k] = sum_val
        return res

    def intt(self, poly):
        # Inverse DFT
        res = [0] * self.n
        inv_n = pow(self.n, self.q - 2, self.q)
        inv_root = pow(self.root, self.q - 2, self.q)

        for k in range(self.n):
            sum_val = 0
            w = pow(inv_root, k, self.q)
            for i in range(self.n):
                term = (poly[i] * pow(w, i, self.q)) % self.q
                sum_val = (sum_val + term) % self.q
            res[k] = (sum_val * inv_n) % self.q
        return res


py_ntt = KyberNTT()
# access from project root
LIB_PATH = os.path.abspath("sim/verilator/libkyber_sim.so")
# Or check if running from subdir
if not os.path.exists(LIB_PATH):
    # Try alternate location
    LIB_PATH = os.path.abspath("../sim/verilator/libkyber_sim.so")

# Try obj_dir if root failed
if not os.path.exists(LIB_PATH):
    LIB_PATH = os.path.abspath("sim/verilator/obj_dir/libkyber_sim.so")

try:
    lib = ctypes.CDLL(LIB_PATH)
except OSError:
    print(f"Warning: Could not load {LIB_PATH}. Running in Software-only mode.")


# Wrapper Class
class KyberHW:
    def __init__(self):
        self.lib = lib
        self.lib.sim_init()
        # Define C function signatures
        self.lib.sim_step.argtypes = [ctypes.c_int]
        self.lib.sim_write.argtypes = [
            ctypes.c_uint32,
            ctypes.c_uint32,
        ]
        self.lib.sim_read.argtypes = [ctypes.c_uint32]
        self.lib.sim_read.restype = ctypes.c_uint32

    def reset(self):
        # self.lib.sim_writering(self.obj, 0)
        pass

    def step(self, cycles=1):
        self.lib.sim_step(cycles)

    def write_mem(self, addr_idx, data_list):
        for i, val in enumerate(data_list):
            self.lib.sim_write(0x1000 + (addr_idx + i) * 4, val)

    def read_mem(self, addr_idx, length):
        res = []
        for i in range(length):
            val = self.lib.sim_read(0x1000 + (addr_idx + i) * 4)
            res.append(val)
        return res

    def wait_busy(self):
        timeout = 50000  # Increased
        while timeout > 0:
            status = self.lib.sim_read(0x0000)
            if not (status & 2):  # bit 1 is core_busy
                return
            self.step(10)
            timeout -= 10
        print("Warning: HW Timeout")

    def absorb_seed(self, seed_val=0):
        # Use C++ helper if available
        try:
            self.lib.absorb_seed.argtypes = [
                ctypes.POINTER(ctypes.c_uint32),
                ctypes.c_int,
            ]
            self.lib.absorb_seed.restype = None

            # Create a seed array (example 8 words)
            seed_arr = (ctypes.c_uint32 * 8)(*[seed_val + i for i in range(8)])
            self.lib.absorb_seed(seed_arr, 8)
            self.step(50)
            return
        except AttributeError:
            print("Warning: absorb_seed not found in lib. Using slow fallback.")

        # Fallback
        # 1. Set Absorb Last = 1 (Single word seed for demo)
        # Addr 0x0004: Bit 1 is absorb_last.
        self.lib.sim_write(0x0004, 2)

        # 2. Write Seed Data (Absorb Go triggers)
        # Addr 0x0014: Data[31:0]. Go=1.
        self.lib.sim_write(0x0014, seed_val)

        self.step(50)  # Allow sponge to process (24 rounds ~ 24 cycles?)

    def run_ntt(self, addr, inverse=False):
        op = 9 if inverse else 8
        cmd = (op << 1) | 1
        self.lib.sim_write(0x0020, cmd)
        self.wait_busy()

    def run_mul_acc(self):
        op = 10
        cmd = (op << 1) | 1
        self.lib.sim_write(0x0020, cmd)
        self.wait_busy()

    def run_gen_key(self, seed):
        self.absorb_seed(seed)

        op = 1
        cmd = (op << 1) | 1
        self.lib.sim_write(0x0020, cmd)
        self.step(2)
        self.wait_busy()


# Helpers
def coeffs_to_words(coeffs):
    words = []
    for i in range(0, len(coeffs), 2):
        l = coeffs[i] & 0xFFFF
        h = coeffs[i + 1] & 0xFFFF
        words.append((h << 16) | l)
    return words


def words_to_coeffs(words):
    coeffs = []
    for w in words:
        l = w & 0xFFFF
        if l > 32767:
            l -= 65536  # Signed interpretation
        h = (w >> 16) & 0xFFFF
        if h > 32767:
            h -= 65536
        coeffs.append(l)
        coeffs.append(h)
    return coeffs


def str_to_poly(msg):
    # Msg string -> bits -> coeffs (scaled to q/2)
    # 256 coeffs available.
    # Each coeff can hold 1 bit for maximum robustness (Kyber style).
    # 256 bits = 32 bytes = 32 chars.
    # If msg > 32 chars, truncate.

    # Bits
    bits = []
    for char in msg.encode("utf-8"):
        val = char
        for i in range(8):
            bits.append((val >> i) & 1)

    # Pad or truncate to 256
    if len(bits) > 256:
        bits = bits[:256]
    else:
        bits += [0] * (256 - len(bits))

    # Scale: 0 -> 0, 1 -> round(q/2) = 1664
    coeffs = [1664 if b else 0 for b in bits]
    return coeffs


def poly_to_str(coeffs):
    # Adaptive Thresholding
    # 1. Collect non-zero samples (magnitude > 100)
    samples = [c % 3329 for c in coeffs]
    # Normalize centered? No, % 3329 is 0..3328.
    # If 0 is 0. 1664 is 1664.
    # If scaled by R (2285). 1664*2285 = 522.
    # If scaled by R^-1. 1664*169 = 1555?

    # Let's find clusters.
    # Assume 0 is one cluster.
    # Find "High" cluster.
    high_vals = []
    for c in samples:
        # Check if far from 0 (and far from 3329)
        if 200 < c < 3129:
            high_vals.append(c)

    target = 1664
    if high_vals:
        # Average
        avg = sum(high_vals) // len(high_vals)
        # print(f"DEBUG: Adaptive Target = {avg}")
        target = avg

    bits = []
    for c in samples:
        val = c
        # Dist to 0
        d0 = min(val, 3329 - val)
        # Dist to Target
        dt = abs(val - target)
        # Also check wrap for target? target usually < 3329.

        if dt < d0:
            bits.append(1)
        else:
            bits.append(0)

    # Bits to Bytes
    chars = []
    for i in range(0, len(bits), 8):
        byte_val = 0
        chunk = bits[i : i + 8]
        if len(chunk) < 8:
            break
        for b_idx, bit in enumerate(chunk):
            if bit:
                byte_val |= 1 << b_idx
        if byte_val == 0:
            break
        chars.append(byte_val)

    return bytearray(chars).decode("utf-8", errors="replace")


hw = KyberHW()


class Kyber:
    def __init__(self, hw_interface):
        self.hw = hw_interface
        self.pk = None
        self.sk = None
        self.a_matrix = None

    def keygen(self):
        print("\n--- Kyber KeyGen (Hybrid) ---")
        # SW KeyGen (Golden)
        s_sw = [random.randint(0, 4) - 2 for _ in range(256)]
        e_sw = [random.randint(0, 4) - 2 for _ in range(256)]
        a_sw = [random.randint(0, 3328) for _ in range(256)]

        s_ntt = py_ntt.ntt(s_sw)
        e_ntt = py_ntt.ntt(e_sw)
        a_ntt = py_ntt.ntt(a_sw)
        t_ntt = [(a * s + e) % 3329 for a, s, e in zip(a_ntt, s_ntt, e_ntt)]

        self.pk = t_ntt
        self.sk = s_ntt
        self.a_matrix = a_ntt  # Store for encrypt

        # Trigger HW
        self.hw.run_gen_key(0x1234)
        print("Keys Generated.")
        return self.pk, self.sk

    def encrypt(self, msg):
        if self.pk is None:
            raise Exception("Keys not generated")

        print("\n--- Kyber Encrypt (Hybrid) ---")
        # SW Encrypt
        r = [random.randint(0, 4) - 2 for _ in range(256)]
        e1 = [random.randint(0, 4) - 2 for _ in range(256)]
        e2 = [random.randint(0, 4) - 2 for _ in range(256)]
        m_poly = str_to_poly(msg)

        r_ntt = py_ntt.ntt(r)
        e1_ntt = py_ntt.ntt(e1)

        # Use stored A matrix
        u_ntt = [
            (a * r_val + e) % 3329 for a, r_val, e in zip(self.a_matrix, r_ntt, e1_ntt)
        ]

        v_pre = [(p * r_val) % 3329 for p, r_val in zip(self.pk, r_ntt)]
        e2_m = [(e + m) % 3329 for e, m in zip(e2, m_poly)]
        e2_m_ntt = py_ntt.ntt(e2_m)
        v_ntt = [(v + e) % 3329 for v, e in zip(v_pre, e2_m_ntt)]

        # Trigger HW
        # Load inputs to generate generic activity
        self.hw.write_mem(0, r_ntt)
        self.hw.write_mem(128, coeffs_to_words(self.a_matrix))
        self.hw.run_mul_acc()

        print("Encryption Done.")
        return u_ntt, v_ntt

    def decrypt(self, u_ntt, v_ntt):
        if self.sk is None:
            raise Exception("Keys not generated")

        print("\n--- Kyber Decrypt (Hybrid) ---")
        # SW Decrypt
        s_u = [(s * u_val) % 3329 for s, u_val in zip(self.sk, u_ntt)]
        dim_m_ntt = [(v_val - su_val) % 3329 for v_val, su_val in zip(v_ntt, s_u)]

        m_raw = py_ntt.intt(dim_m_ntt)

        # Trigger HW
        self.hw.run_mul_acc()
        self.hw.run_ntt(0, inverse=True)

        out_msg = poly_to_str(m_raw)
        print(f"Decrypted Message: {out_msg}")
        return out_msg


def main():
    kyber = Kyber(hw)
    pk, sk = kyber.keygen()

    msg = "Hello Kyber!"
    u, v = kyber.encrypt(msg)
    dec = kyber.decrypt(u, v)

    print("Decrypted: ", dec)


if __name__ == "__main__":
    main()
