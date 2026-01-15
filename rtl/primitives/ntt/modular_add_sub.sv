module modular_add_sub
import ntt_pkg:
       :
         *;
  (
    input  logic [DATA_WIDTH-1:0] a,
    input  logic [DATA_WIDTH-1:0] b,
    output logic [DATA_WIDTH-1:0] sum,
    output logic [DATA_WIDTH-1:0] diff
  );

  // Addition: (a + b) mod q
  // Logic: res = a + b; if (res >= q) res -= q; (assuming a,b < q)
  logic [DATA_WIDTH:0] raw_sum;
  logic [DATA_WIDTH:0] raw_sum_minus_q;

  always_comb
  begin
    raw_sum = a + b;
    raw_sum_minus_q = raw_sum - KYBER_Q;

    if (raw_sum >= KYBER_Q)
      sum = raw_sum_minus_q[DATA_WIDTH-1:0];
    else
      sum = raw_sum[DATA_WIDTH-1:0];
  end

  // Subtraction: (a - b) mod q
  // Logic: res = a - b; if (res < 0) res += q;
  // Implementation: res = a + (q - b) if a < b else a - b?
  // Or: raw_diff = a - b; if borrow, add q.
  logic [DATA_WIDTH:0] raw_diff;

  always_comb
  begin
    if (a >= b)
    begin
      diff = a - b;
    end
    else
    begin
      diff = (a + KYBER_Q) - b;
    end
  end

endmodule
