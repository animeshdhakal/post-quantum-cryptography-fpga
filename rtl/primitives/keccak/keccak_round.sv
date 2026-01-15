module keccak_round (
    input  logic [4:0]  round_idx,
    input  logic [63:0] state_in [4:0][4:0], // 5x5 lanes of 64 bits
    output logic [63:0] state_out[4:0][4:0]
  );

  // Function to get Round Constants (Inlined to avoid package issues)
  function automatic logic [63:0] get_iota_rc(input logic [4:0] idx);
    case (idx)
      5'd0:
        return 64'h0000000000000001;
      5'd1:
        return 64'h0000000000008082;
      5'd2:
        return 64'h800000000000808a;
      5'd3:
        return 64'h8000000080008000;
      5'd4:
        return 64'h000000000000808b;
      5'd5:
        return 64'h0000000080000001;
      5'd6:
        return 64'h8000000080008081;
      5'd7:
        return 64'h8000000000008009;
      5'd8:
        return 64'h000000000000008a;
      5'd9:
        return 64'h0000000000000088;
      5'd10:
        return 64'h0000000080008009;
      5'd11:
        return 64'h000000008000000a;
      5'd12:
        return 64'h000000008000808b;
      5'd13:
        return 64'h800000000000008b;
      5'd14:
        return 64'h8000000000008089;
      5'd15:
        return 64'h8000000000008003;
      5'd16:
        return 64'h8000000000008002;
      5'd17:
        return 64'h8000000000000080;
      5'd18:
        return 64'h000000000000800a;
      5'd19:
        return 64'h800000008000000a;
      5'd20:
        return 64'h8000000080008081;
      5'd21:
        return 64'h8000000000008080;
      5'd22:
        return 64'h0000000080000001;
      5'd23:
        return 64'h8000000080008008;
      default:
        return 64'd0;
    endcase
  endfunction

  logic [63:0] theta_c[4:0];
  logic [63:0] theta_d[4:0];
  logic [63:0] state_theta[4:0][4:0];
  logic [63:0] state_rho[4:0][4:0];
  logic [63:0] state_pi[4:0][4:0];
  logic [63:0] state_chi[4:0][4:0];
  logic [63:0] state_iota[4:0][4:0];

  // =========================================================================
  // 1. Theta Step
  // =========================================================================
  // Compute parity of columns
  always_comb
  begin
    for (int x = 0; x < 5; x++)
    begin
      theta_c[x] = state_in[x][0] ^ state_in[x][1] ^ state_in[x][2] ^ state_in[x][3] ^ state_in[x][4];
    end
  end

  // Compute mixing value D
  always_comb
  begin
    for (int x = 0; x < 5; x++)
    begin
      theta_d[x] = theta_c[(x+4)%5] ^ {theta_c[(x+1)%5][62:0], theta_c[(x+1)%5][63]}; // Rot(C[x+1], 1)
    end
  end

  // Apply Theta
  always_comb
  begin
    for (int x = 0; x < 5; x++)
    begin
      for (int y = 0; y < 5; y++)
      begin
        state_theta[x][y] = state_in[x][y] ^ theta_d[x];
      end
    end
  end

  // =========================================================================
  // 2. Rho Step
  // =========================================================================
  // Rotation offsets for each lane (x, y)
  const int RHO_OFFSETS[5][5] = '{
          '{ 0, 36,  3, 41, 18},
          '{ 1, 44, 10, 45,  2},
          '{62,  6, 43, 15, 61},
          '{28, 55, 25, 21, 56},
          '{27, 20, 39,  8, 14}
        };

  always_comb
  begin
    for (int x = 0; x < 5; x++)
    begin
      for (int y = 0; y < 5; y++)
      begin
        if (RHO_OFFSETS[x][y] == 0)
        begin
          state_rho[x][y] = state_theta[x][y];
        end
        else
        begin
          // Cyclic rotate left
          state_rho[x][y] = (state_theta[x][y] << RHO_OFFSETS[x][y]) | (state_theta[x][y] >> (64 - RHO_OFFSETS[x][y]));
        end
      end
    end
  end

  // =========================================================================
  // 3. Pi Step
  // =========================================================================
  // Permute lanes: A'[x][y] = A[x + 3y][x]
  always_comb
  begin
    for (int x = 0; x < 5; x++)
    begin
      for (int y = 0; y < 5; y++)
      begin
        state_pi[x][y] = state_rho[(x + 3*y)%5][x];
      end
    end
  end

  // =========================================================================
  // 4. Chi Step
  // =========================================================================
  // A'[x][y] = A[x][y] ^ ((~A[x+1][y]) & A[x+2][y])
  always_comb
  begin
    for (int x = 0; x < 5; x++)
    begin
      for (int y = 0; y < 5; y++)
      begin
        state_chi[x][y] = state_pi[x][y] ^ ((~state_pi[(x+1)%5][y]) & state_pi[(x+2)%5][y]);
      end
    end
  end

  // =========================================================================
  // 5. Iota Step
  // =========================================================================
  // XOR lane (0,0) with round constant
  always_comb
  begin
    state_iota = state_chi;
    state_iota[0][0] = state_chi[0][0] ^ get_iota_rc(round_idx);
  end

  assign state_out = state_iota;

endmodule
