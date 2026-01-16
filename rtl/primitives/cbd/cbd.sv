module cbd (
    input  logic        clk,
    input  logic        rst_n,

    // Input Interface (from Sponge)
    input  logic        start,   // Asserted when in_data is valid
    input  logic [63:0] in_data, // 64-bit word from Keccak (contains 16 coeffs for Eta=2)

    // Output Interface (to RAM)
    output logic [31:0] out_data, // 2 packed 16-bit coefficients
    output logic        valid,    // valid signal for RAM write
    output logic        done      // ready for next input
  );

  // =========================================================================
  // Parameters (Kyber-512 uses Eta=2)
  // =========================================================================
  // Eta = 2 means each coefficient consumes 2*Eta = 4 bits from input.
  // 64 bits input / 4 = 16 coefficients.
  // We output 2 coefficients per cycle (32-bit bus).
  // So we need 8 cycles.

  logic [63:0] data_reg;
  logic [2:0]  cnt; // 0 to 7
  logic        active;

  always_ff @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      active <= 0;
      cnt <= 0;
      done <= 1; // Initially ready
      valid <= 0;
      data_reg <= 0;
    end
    else
    begin
      valid <= 0;
      done <= 0;

      if (active)
      begin
        valid <= 1;
        if (cnt == 3'd7)
        begin
          active <= 0;
          done <= 1; // Signal done after last write
          cnt <= 0;
        end
        else
        begin
          cnt <= cnt + 1;
        end
      end
      else if (start)
      begin
        data_reg <= in_data;
        active <= 1;
        cnt <= 0;
        done <= 0;
        valid <= 0; // First valid will be next cycle?
        // Actually if valid <= 1 is in active block, it triggers next cycle.
        // We want immediate? Or registered?
        // Registered is safer.
        // cycle 0: Start.
        // cycle 1: Active=1. Valid=1 (Output 0).
        // ...
        // cycle 8: Valid=1 (Output 7). Done=1.
      end
      else
      begin
        done <= 1;
      end
    end
  end

  // Combinational logic to select 8 bits (2 coeffs) based on cnt
  logic [7:0] current_byte;

  // cnt=0 -> bits [7:0]
  // cnt=1 -> bits [15:8]
  // ...
  // cnt=7 -> bits [63:56]
  assign current_byte = data_reg[cnt*8 +: 8];

  // Coefficient 0 (Low 4 bits)
  // d = d0 + d1 + ...
  // a = bit0 + bit1
  // b = bit2 + bit3
  logic [1:0] a0, b0;
  logic [1:0] a1, b1;

  logic signed [2:0] res0, res1;

  // Coeff 0 from bits [3:0]
  assign a0 = current_byte[0] + current_byte[1];
  assign b0 = current_byte[2] + current_byte[3];
  assign res0 = signed'({1'b0, a0}) - signed'({1'b0, b0});

  // Coeff 1 from bits [7:4]
  assign a1 = current_byte[4] + current_byte[5];
  assign b1 = current_byte[6] + current_byte[7];
  assign res1 = signed'({1'b0, a1}) - signed'({1'b0, b1});

  // Sign Extend to 16 bits
  // 3-bit signed (-2..2).
  // If res0 is negative (e.g. -2 = 110), we extend sign.

  function automatic logic [15:0] to_positive(input logic signed [2:0] in);
    logic signed [15:0] ext;
    ext = {{13{in[2]}}, in}; // Sign extend
    if (ext < 0)
      return (16'd3329 + ext); // e.g. -1 -> 3328
    else
      return ext;
  endfunction

  assign out_data = {to_positive(res1), to_positive(res0)};


endmodule
