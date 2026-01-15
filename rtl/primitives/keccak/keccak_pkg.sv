package keccak_pkg;
    // 64-bit Iota Constants for the 24 rounds of Keccak-f[1600]
    function automatic logic [63:0] get_iota_rc(input logic [4:0] round_idx);
        case (round_idx)
            5'd0:  return 64'h0000000000000001;
            5'd1:  return 64'h0000000000008082;
            5'd2:  return 64'h800000000000808a;
            5'd3:  return 64'h8000000080008000;
            5'd4:  return 64'h000000000000808b;
            5'd5:  return 64'h0000000080000001;
            5'd6:  return 64'h8000000080008081;
            5'd7:  return 64'h8000000000008009;
            5'd8:  return 64'h000000000000008a;
            5'd9:  return 64'h0000000000000088;
            5'd10: return 64'h0000000080008009;
            5'd11: return 64'h000000008000000a;
            5'd12: return 64'h000000008000808b;
            5'd13: return 64'h800000000000008b;
            5'd14: return 64'h8000000000008089;
            5'd15: return 64'h8000000000008003;
            5'd16: return 64'h8000000000008002;
            5'd17: return 64'h8000000000000080;
            5'd18: return 64'h000000000000800a;
            5'd19: return 64'h800000008000000a;
            5'd20: return 64'h8000000080008081;
            5'd21: return 64'h8000000000008080;
            5'd22: return 64'h0000000080000001;
            5'd23: return 64'h8000000080008008;
            default: return 64'd0;
        endcase
    endfunction
endpackage
