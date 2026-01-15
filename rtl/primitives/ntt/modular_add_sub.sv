module modular_add_sub (
    input  logic [15:0] a,
    input  logic [15:0] b,
    output logic [15:0] sum,
    output logic [15:0] diff
  );

  localparam int KYBER_Q = 3329;

  // Addition: (a + b) mod q
  logic [16:0] raw_sum;
  logic [16:0] raw_sum_minus_q;

  always_comb
  begin
    raw_sum = {1'b0, a} + {1'b0, b};
    // Explicit 17-bit math
    raw_sum_minus_q = raw_sum - 17'(KYBER_Q);

    if (raw_sum >= 17'(KYBER_Q))
      sum = raw_sum_minus_q[15:0];
    else
      sum = raw_sum[15:0];
  end

  // Subtraction: (a - b) mod q
  always_comb
  begin
    if (a >= b)
    begin
      // Cast to 32 bits for safety then truncate
      diff = 16'(32'(a) - 32'(b));
    end
    else
    begin
      diff = 16'((32'(a) + 32'(KYBER_Q)) - 32'(b));
    end
  end

endmodule
