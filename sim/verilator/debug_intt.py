Q = 3329
ROOT_OF_UNITY = 17


def bit_reverse(n, bits):
    result = 0
    for _ in range(bits):
        result = (result << 1) | (n & 1)
        n >>= 1
    return result


def hw_mul(a, b):
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


def debug_run():
    print("Generating Zetas...")
    zetas = [0] * 128
    val = 1
    mont_r = (1 << 16) % Q
    for i in range(128):
        zetas[bit_reverse(i, 7)] = (val * mont_r) % Q
        val = (val * ROOT_OF_UNITY) % Q

    print(f"Zetas[0] (should be unused/Mont(1)): {zetas[0]}")
    print(f"Zetas[1] (Mont(root^64)): {zetas[1]}")

    # Inverse Zetas
    zetas_inv_table = []
    r2 = (mont_r * mont_r) % Q
    for z in zetas:
        inv = mod_inverse(z)
        target = (inv * r2) % Q
        zetas_inv_table.append(target)

    print(f"InvZeta[1]: {zetas_inv_table[1]}")

    check = hw_mul(zetas[1], zetas_inv_table[1])
    print(f"Check Zeta[1]*InvZeta[1] (Expected 2285): {check}")

    # Debug Poly (Random)
    import random

    random.seed(42)
    poly = [random.randint(0, Q - 1) for _ in range(256)]

    # Forward NTT
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

    fwd = list(res)
    # print(f"NTT(Random)[0..4]: {fwd[0:5]}")

    # Inverse NTT
    res = list(fwd)

    length = 2
    while length <= 128:
        start = 0
        # Determine starting k for this layer
        # For len=2, we used zetas[64..127] (Forward).
        # So we should use zetas[64..127]^-1 (Inverse).
        k = 128 // length

        while start < 256:
            zeta = zetas_inv_table[k]
            k += 1  # Increment k!

            for j in range(start, start + length):
                # Gentleman-Sande
                # sum, diff = hw_add_sub(U, 0, V)
                # U' = sum
                # V' = diff * zeta
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

    mismatches = 0
    for i in range(256):
        if res[i] != poly[i]:
            mismatches += 1
            if mismatches < 5:
                print(f"Mismatch {i}: Orig {poly[i]} != Inv {res[i]}")

    if mismatches == 0:
        print("SUCCESS: Random Poly Inverted Correctly")
        # Dump Verilog
        print("// Inverse Zetas")
        print("function automatic logic [15:0] get_zeta_inv(input logic [6:0] idx);")
        print("    case (idx)")
        for i, val in enumerate(zetas_inv_table):
            print(f"        7'd{i}: return 16'd{val};")
        print("        default: return 16'd0;")
        print("    endcase")
        print("endfunction")
    else:
        print(f"FAILURE: {mismatches} mismatches")


if __name__ == "__main__":
    debug_run()
