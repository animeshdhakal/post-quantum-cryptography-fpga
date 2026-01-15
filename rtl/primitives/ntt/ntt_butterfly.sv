module ntt_butterfly (
    input  logic signed [15:0] a,
    input  logic signed [15:0] b,
    input  logic signed [15:0] w, // Twiddle factor
    input  logic               mode, // 0=CT (NTT), 1=GS (INTT)
    output logic signed [15:0] out_a,
    output logic signed [15:0] out_b
  );

  logic signed [15:0] mul_in_a;
  logic signed [15:0] mul_out;
  logic signed [15:0] add_in_b;
  /* verilator lint_off UNOPTFLAT */
  logic signed [15:0] sum, diff;
  /* verilator lint_on UNOPTFLAT */

  // Mode Muxing
  // CT: mul happens first (b*w), then add/sub (a +/- bw)
  // GS: add/sub happens first (a +/- b), then mul ((a-b)*w)

  assign mul_in_a = (mode) ? diff : b;
  assign add_in_b = (mode) ? b : mul_out;

  // Multiplier
  ntt_mul u_mul (
            .a(mul_in_a),
            .b(w),
            .out(mul_out)
          );

  // Add/Sub
  modular_add_sub u_add_sub (
                    .a(a),
                    .b(add_in_b),
                    .sum(sum),
                    .diff(diff)
                  );

  // Output Muxing
  // CT: out_a = sum, out_b = diff
  // GS: out_a = sum, out_b = mul_out
  assign out_a = sum;
  assign out_b = (mode) ? mul_out : diff;

endmodule
