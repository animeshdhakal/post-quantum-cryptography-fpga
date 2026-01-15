module ntt_mul (
    input  logic signed [15:0] a, // 16-bit signed coefficient
    input  logic signed [15:0] b,
    output logic signed [15:0] out
  );

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
    // Explicit cast to 16 bits to appease linter
    m = 16'(signed'(product) * signed'(QINV));

    // 3. u = (product - m * Q) / R
    mq = 32'(m) * 32'(Q);
    t_sub_mq = product - mq;

    // shift right 16
    res = t_sub_mq[31:16];

    // 4. Final correction to [0, Q-1]
    // Standard Montgomery can return result in (-Q, Q) or (0, 2Q).
    // We enforce canonical [0, Q-1] for compatibility with modular_add_sub.

    if (res >= Q)
      out = res - Q;
    else if (res < 0)
      out = res + Q;
    else
      out = res;
  end

endmodule
