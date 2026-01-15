module ntt_mul
import ntt_pkg:
       :
         *;
  (
    input  logic signed [15:0] a, // 16-bit signed coefficient
    input  logic signed [15:0] b,
    output logic signed [15:0] out
  );

  // Kyber Q = 3329
  // QINV = -3329^-1 mod 2^16 = 62209 (or -3327 interpreted as signed 16-bit)
  // -3327 = 0xF301.
  // Let's use signed arithmetic as per reference C implementation commonly used.

  localparam signed [15:0] Q = 3329;
  localparam signed [15:0] QINV = -3327; // 0xF301

  logic signed [31:0] product;
  logic signed [15:0] m;
  logic signed [31:0] mq;
  logic signed [31:0] t_sub_mq;
  logic signed [15:0] res;

  always_comb
  begin
    // 1. Product
    product = signed'(32'(a) * 32'(b));

    // 2. Montgomery reduction
    // m = product * QINV mod 2^16
    m = signed'(product) * signed'(QINV);
    // Note: we strictly want the lower 16 bits, so this cast works.

    // 3. u = (product - m * Q) / R
    // R = 2^16, so division is shift.
    mq = 32'(m) * 32'(Q);
    t_sub_mq = product - mq;

    // shift right 16
    res = t_sub_mq[31:16];

    // Final conditional subtraction if required?
    // Montgomery reduction output is in range (-q, q) typically if inputs are proper.
    // Kyber reference often allows redundancy.
    // Standard "Reduce" function:
    // return t;

    out = res;
  end

endmodule
