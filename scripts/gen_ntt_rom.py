def bit_reverse(n, width):
    b = "{:0{width}b}".format(n, width=width)
    return int(b[::-1], 2)


def gen_rom():
    q = 3329
    root_of_unity = 17
    # Montgomery factor 2^16 mod q
    mont_r = (1 << 16) % q

    # Pre-compute zetas
    # Kyber Zetas are usually defined as BitRev(i) index?
    # Or typically the table is generated such that we access it sequentially
    # during the Cooley-Tukey butterfly.
    # Standard Kyber loop (from ref implementation):
    # k = 1
    # for len in [128, 64, 32, 16, 8, 4, 2]:
    #   for start in 0..255 step 2*len:
    #     zeta = zetas[k]; k++
    #     ...
    # So we want the zetas in the order they are used.
    # The reference 'zetas' array is 128 elements.

    zetas = [0] * 128

    # Generate powers of root
    # In Kyber reference, zetas are precomputed bit-reversed.
    # But wait, looking at ref code:
    # zetas[i] = mont_mul(root^bitrev(i), R) ?
    # Let's generate them simply as powers for now, but ordered correctly.
    # Actually, to avoid confusion, let's use the explicit table generation logic from standard scripts
    # or just simple powers if we trust our address generator to handle it.
    # BUT, the simple CT butterfly walks k++.

    # Let's calculate standard bit-reversed order zetas in Montgomery form.

    def mont_mul(a, b):
        return (
            a * b
        ) % q  # Python handles large ints, no need for reduction logic here strictly

    # Calculate table
    # We need 128 zetas.
    output_vals = []

    # We track the 'k' index from the reference C code logic to ensure we match order.
    # Ref:
    #   k = 1;
    #   for (len = 128; len >= 2; len >>= 1) {
    #     for (start = 0; start < 256; start += 2 * len) {
    #        zeta = zetas[k];
    #        ...
    #     }
    #     k++; (wait, k increments in the outer loop? No, usually per butterfly group)
    #   }

    # Re-reading Kyber spec / ref code (poly.c ntt):
    # k = 1;
    # for(len=128; len>=2; len>>=1) {
    #   for(start=0; start<256; start+=2*len) {
    #     zeta = zetas[k++]; // k increments here!
    #     for(j=start; j<start+len; j++) { ... }
    #   }
    # }
    # So k goes 1..127.

    # We need to generate the 'zetas' array that matches this access pattern.
    # The 'zetas' array in usage is bit-reversed powers of root.

    # Let's write the SystemVerilog

    sv_header = """package ntt_rom_pkg;
    // Zetas in Montgomery Domain (x * 2^16 mod 3329)
    // Order matches Cooley-Tukey processing order (k=1..127)
    function automatic logic [15:0] get_zeta(input logic [6:0] idx);
        case (idx)"""

    sv_footer = """            default: return 16'd0;
        endcase
    endfunction
endpackage"""

    # Calculate powers
    # root = 17
    # mont_r = 2285
    powers = []
    val = 1
    for i in range(128):
        # Montgomery transform
        mont_val = (val * mont_r) % q
        powers.append(mont_val)
        val = (val * root_of_unity) % q

    # Bit reverse index
    def br7(i):
        # Bit reverse 7 bits
        return int("{:07b}".format(i)[::-1], 2)

    zetas_mont = [powers[br7(i)] for i in range(128)]

    # We only use indices 1 to 127 in the standard loop. Index 0 is not used?
    # Actually, let's just dump the whole 0..127 table. The HW will index it.

    print(sv_header)
    for i in range(128):
        print(f"            7'd{i}: return 16'd{zetas_mont[i]};")
    print(sv_footer)


if __name__ == "__main__":
    gen_rom()
