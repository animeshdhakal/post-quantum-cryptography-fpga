module ntt_core (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic        mode, // 0=NTT, 1=INTT

    // Memory Interface (External Load/Store)
    input  logic        mem_wr_en,
    input  logic [7:0]  mem_wr_addr,
    input  logic [15:0] mem_wr_data,

    input  logic [7:0]  mem_rd_addr,
    output logic [15:0] mem_rd_data,

    output logic        done,
    output logic        busy
  );

  // Inlined ROM Data to bypass Verilator Package issues
  function automatic logic [15:0] get_zeta(input logic [6:0] idx);
    case (idx)
      7'd0:
        return 16'd2285;
      7'd1:
        return 16'd2571;
      7'd2:
        return 16'd2970;
      7'd3:
        return 16'd1812;
      7'd4:
        return 16'd1493;
      7'd5:
        return 16'd1422;
      7'd6:
        return 16'd287;
      7'd7:
        return 16'd202;
      7'd8:
        return 16'd3158;
      7'd9:
        return 16'd622;
      7'd10:
        return 16'd1577;
      7'd11:
        return 16'd182;
      7'd12:
        return 16'd962;
      7'd13:
        return 16'd2127;
      7'd14:
        return 16'd1855;
      7'd15:
        return 16'd1468;
      7'd16:
        return 16'd573;
      7'd17:
        return 16'd2004;
      7'd18:
        return 16'd264;
      7'd19:
        return 16'd383;
      7'd20:
        return 16'd2500;
      7'd21:
        return 16'd1458;
      7'd22:
        return 16'd1727;
      7'd23:
        return 16'd3199;
      7'd24:
        return 16'd2648;
      7'd25:
        return 16'd1017;
      7'd26:
        return 16'd732;
      7'd27:
        return 16'd608;
      7'd28:
        return 16'd1787;
      7'd29:
        return 16'd411;
      7'd30:
        return 16'd3124;
      7'd31:
        return 16'd1758;
      7'd32:
        return 16'd1223;
      7'd33:
        return 16'd652;
      7'd34:
        return 16'd2777;
      7'd35:
        return 16'd1015;
      7'd36:
        return 16'd2036;
      7'd37:
        return 16'd1491;
      7'd38:
        return 16'd3047;
      7'd39:
        return 16'd1785;
      7'd40:
        return 16'd516;
      7'd41:
        return 16'd3321;
      7'd42:
        return 16'd3009;
      7'd43:
        return 16'd2663;
      7'd44:
        return 16'd1711;
      7'd45:
        return 16'd2167;
      7'd46:
        return 16'd126;
      7'd47:
        return 16'd1469;
      7'd48:
        return 16'd2476;
      7'd49:
        return 16'd3239;
      7'd50:
        return 16'd3058;
      7'd51:
        return 16'd830;
      7'd52:
        return 16'd107;
      7'd53:
        return 16'd1908;
      7'd54:
        return 16'd3082;
      7'd55:
        return 16'd2378;
      7'd56:
        return 16'd2931;
      7'd57:
        return 16'd961;
      7'd58:
        return 16'd1821;
      7'd59:
        return 16'd2604;
      7'd60:
        return 16'd448;
      7'd61:
        return 16'd2264;
      7'd62:
        return 16'd677;
      7'd63:
        return 16'd2054;
      7'd64:
        return 16'd2226;
      7'd65:
        return 16'd430;
      7'd66:
        return 16'd555;
      7'd67:
        return 16'd843;
      7'd68:
        return 16'd2078;
      7'd69:
        return 16'd871;
      7'd70:
        return 16'd1550;
      7'd71:
        return 16'd105;
      7'd72:
        return 16'd422;
      7'd73:
        return 16'd587;
      7'd74:
        return 16'd177;
      7'd75:
        return 16'd3094;
      7'd76:
        return 16'd3038;
      7'd77:
        return 16'd2869;
      7'd78:
        return 16'd1574;
      7'd79:
        return 16'd1653;
      7'd80:
        return 16'd3083;
      7'd81:
        return 16'd778;
      7'd82:
        return 16'd1159;
      7'd83:
        return 16'd3182;
      7'd84:
        return 16'd2552;
      7'd85:
        return 16'd1483;
      7'd86:
        return 16'd2727;
      7'd87:
        return 16'd1119;
      7'd88:
        return 16'd1739;
      7'd89:
        return 16'd644;
      7'd90:
        return 16'd2457;
      7'd91:
        return 16'd349;
      7'd92:
        return 16'd418;
      7'd93:
        return 16'd329;
      7'd94:
        return 16'd3173;
      7'd95:
        return 16'd3254;
      7'd96:
        return 16'd817;
      7'd97:
        return 16'd1097;
      7'd98:
        return 16'd603;
      7'd99:
        return 16'd610;
      7'd100:
        return 16'd1322;
      7'd101:
        return 16'd2044;
      7'd102:
        return 16'd1864;
      7'd103:
        return 16'd384;
      7'd104:
        return 16'd2114;
      7'd105:
        return 16'd3193;
      7'd106:
        return 16'd1218;
      7'd107:
        return 16'd1994;
      7'd108:
        return 16'd2455;
      7'd109:
        return 16'd220;
      7'd110:
        return 16'd2142;
      7'd111:
        return 16'd1670;
      7'd112:
        return 16'd2144;
      7'd113:
        return 16'd1799;
      7'd114:
        return 16'd2051;
      7'd115:
        return 16'd794;
      7'd116:
        return 16'd1819;
      7'd117:
        return 16'd2475;
      7'd118:
        return 16'd2459;
      7'd119:
        return 16'd478;
      7'd120:
        return 16'd3221;
      7'd121:
        return 16'd3021;
      7'd122:
        return 16'd996;
      7'd123:
        return 16'd991;
      7'd124:
        return 16'd958;
      7'd125:
        return 16'd1869;
      7'd126:
        return 16'd1522;
      7'd127:
        return 16'd1628;
      default:
        return 16'd0;
    endcase
  endfunction

  // Inverse Zetas
  function automatic logic [15:0] get_zeta_inv(input logic [6:0] idx);
    case (idx)
      7'd0:
        return 16'd2285;
      7'd1:
        return 16'd758;
      7'd2:
        return 16'd1517;
      7'd3:
        return 16'd359;
      7'd4:
        return 16'd3127;
      7'd5:
        return 16'd3042;
      7'd6:
        return 16'd1907;
      7'd7:
        return 16'd1836;
      7'd8:
        return 16'd1861;
      7'd9:
        return 16'd1474;
      7'd10:
        return 16'd1202;
      7'd11:
        return 16'd2367;
      7'd12:
        return 16'd3147;
      7'd13:
        return 16'd1752;
      7'd14:
        return 16'd2707;
      7'd15:
        return 16'd171;
      7'd16:
        return 16'd1571;
      7'd17:
        return 16'd205;
      7'd18:
        return 16'd2918;
      7'd19:
        return 16'd1542;
      7'd20:
        return 16'd2721;
      7'd21:
        return 16'd2597;
      7'd22:
        return 16'd2312;
      7'd23:
        return 16'd681;
      7'd24:
        return 16'd130;
      7'd25:
        return 16'd1602;
      7'd26:
        return 16'd1871;
      7'd27:
        return 16'd829;
      7'd28:
        return 16'd2946;
      7'd29:
        return 16'd3065;
      7'd30:
        return 16'd1325;
      7'd31:
        return 16'd2756;
      7'd32:
        return 16'd1275;
      7'd33:
        return 16'd2652;
      7'd34:
        return 16'd1065;
      7'd35:
        return 16'd2881;
      7'd36:
        return 16'd725;
      7'd37:
        return 16'd1508;
      7'd38:
        return 16'd2368;
      7'd39:
        return 16'd398;
      7'd40:
        return 16'd951;
      7'd41:
        return 16'd247;
      7'd42:
        return 16'd1421;
      7'd43:
        return 16'd3222;
      7'd44:
        return 16'd2499;
      7'd45:
        return 16'd271;
      7'd46:
        return 16'd90;
      7'd47:
        return 16'd853;
      7'd48:
        return 16'd1860;
      7'd49:
        return 16'd3203;
      7'd50:
        return 16'd1162;
      7'd51:
        return 16'd1618;
      7'd52:
        return 16'd666;
      7'd53:
        return 16'd320;
      7'd54:
        return 16'd8;
      7'd55:
        return 16'd2813;
      7'd56:
        return 16'd1544;
      7'd57:
        return 16'd282;
      7'd58:
        return 16'd1838;
      7'd59:
        return 16'd1293;
      7'd60:
        return 16'd2314;
      7'd61:
        return 16'd552;
      7'd62:
        return 16'd2677;
      7'd63:
        return 16'd2106;
      7'd64:
        return 16'd1701;
      7'd65:
        return 16'd1807;
      7'd66:
        return 16'd1460;
      7'd67:
        return 16'd2371;
      7'd68:
        return 16'd2338;
      7'd69:
        return 16'd2333;
      7'd70:
        return 16'd308;
      7'd71:
        return 16'd108;
      7'd72:
        return 16'd2851;
      7'd73:
        return 16'd870;
      7'd74:
        return 16'd854;
      7'd75:
        return 16'd1510;
      7'd76:
        return 16'd2535;
      7'd77:
        return 16'd1278;
      7'd78:
        return 16'd1530;
      7'd79:
        return 16'd1185;
      7'd80:
        return 16'd1659;
      7'd81:
        return 16'd1187;
      7'd82:
        return 16'd3109;
      7'd83:
        return 16'd874;
      7'd84:
        return 16'd1335;
      7'd85:
        return 16'd2111;
      7'd86:
        return 16'd136;
      7'd87:
        return 16'd1215;
      7'd88:
        return 16'd2945;
      7'd89:
        return 16'd1465;
      7'd90:
        return 16'd1285;
      7'd91:
        return 16'd2007;
      7'd92:
        return 16'd2719;
      7'd93:
        return 16'd2726;
      7'd94:
        return 16'd2232;
      7'd95:
        return 16'd2512;
      7'd96:
        return 16'd75;
      7'd97:
        return 16'd156;
      7'd98:
        return 16'd3000;
      7'd99:
        return 16'd2911;
      7'd100:
        return 16'd2980;
      7'd101:
        return 16'd872;
      7'd102:
        return 16'd2685;
      7'd103:
        return 16'd1590;
      7'd104:
        return 16'd2210;
      7'd105:
        return 16'd602;
      7'd106:
        return 16'd1846;
      7'd107:
        return 16'd777;
      7'd108:
        return 16'd147;
      7'd109:
        return 16'd2170;
      7'd110:
        return 16'd2551;
      7'd111:
        return 16'd246;
      7'd112:
        return 16'd1676;
      7'd113:
        return 16'd1755;
      7'd114:
        return 16'd460;
      7'd115:
        return 16'd291;
      7'd116:
        return 16'd235;
      7'd117:
        return 16'd3152;
      7'd118:
        return 16'd2742;
      7'd119:
        return 16'd2907;
      7'd120:
        return 16'd3224;
      7'd121:
        return 16'd1779;
      7'd122:
        return 16'd2458;
      7'd123:
        return 16'd1251;
      7'd124:
        return 16'd2486;
      7'd125:
        return 16'd2774;
      7'd126:
        return 16'd2899;
      7'd127:
        return 16'd1103;
      default:
        return 16'd0;
    endcase
  endfunction

  // Internal Memory: 256 x 16
  logic [15:0] mem [255:0];

  // Butterfly Signals
  logic [15:0] bf_a, bf_b;
  logic [15:0] bf_out_a, bf_out_b;

  ntt_butterfly u_bf (
                  .a(bf_a),
                  .b(bf_b),
                  .w(current_zeta), // Direct connection
                  .mode(mode),
                  .out_a(bf_out_a),
                  .out_b(bf_out_b)
                );

  // State Machine
  typedef enum logic [2:0] {IDLE, LAYER, SCALING, DONE} state_t;
  state_t state;

  // Loop Counters
  logic [7:0] len;   // 128, 64...
  logic [7:0] start_idx;
  logic [7:0] j_idx;
  logic [6:0] k_zeta; // Zeta index 1..127
  logic [15:0] current_zeta;

  // Sub-steps for single-port simulation emulation
  logic [1:0] sub_step; // 0=Ra, 1=Rb, 2=Wa, 3=Wb

  // Internal Memory Control Signals
  logic        core_mem_we;
  logic [7:0]  core_mem_addr;
  logic [15:0] core_mem_wdata;

  // Final Memory Control Mux
  logic        final_mem_we;
  logic [7:0]  final_mem_addr;
  logic [15:0] final_mem_wdata;

  // Scaling Factor Logic
  logic [15:0] scaling_factor;
  assign scaling_factor = 16'd512; // Mont(128^-1) corrected

  // Busy Logic: Must remain high if internal write is pending (core_mem_we registered)
  assign busy = (state != IDLE && state != DONE) || core_mem_we;

  // Mux Logic: Priority to Core when Busy
  always_comb
  begin
    if (busy)
    begin
      final_mem_we    = core_mem_we;
      final_mem_addr  = core_mem_addr;
      final_mem_wdata = core_mem_wdata;
    end
    else
    begin
      final_mem_we    = mem_wr_en;
      final_mem_addr  = mem_wr_addr;
      final_mem_wdata = mem_wr_data;
    end
  end

  // Sync Write Port
  always_ff @(posedge clk)
  begin
    if (final_mem_we)
    begin
      mem[final_mem_addr] <= final_mem_wdata;
    end
  end

  // Async Read Port (External)
  assign mem_rd_data = mem[mem_rd_addr];

  always_ff @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      state <= IDLE;
      len <= 8'd128; // Default
      start_idx <= 8'd0;
      j_idx <= 8'd0;
      k_zeta <= 7'd1;
      done <= 1'b0;
      sub_step <= 2'd0;

      core_mem_we <= 1'b0;
      core_mem_addr <= 8'd0;
      core_mem_wdata <= 16'd0;
    end
    else
    begin
      done <= 1'b0;
      core_mem_we <= 1'b0; // Default

      case (state)
        IDLE:
        begin
          if (start)
          begin
            state <= LAYER;
            sub_step <= 2'd0;
            start_idx <= 8'd0;
            j_idx <= 8'd0;

            if (mode == 1'b0)
            begin
              // NTT
              len <= 8'd128;
              k_zeta <= 7'd1;
            end
            else
            begin
              // INTT
              len <= 8'd2;
              k_zeta <= 7'd64; // Init for len=2 (128/2)
            end
          end
        end

        LAYER:
        begin
          case (sub_step)
            2'd0:
            begin // Read A
              bf_a <= mem[j_idx]; // Async internal read
              sub_step <= 2'd1;
            end

            2'd1:
            begin // Read B
              bf_b <= mem[j_idx + len];
              if (mode == 1'b0)
                current_zeta <= get_zeta(k_zeta);
              else
                current_zeta <= get_zeta_inv(k_zeta);

              sub_step <= 2'd2;
            end

            2'd2:
            begin // Write A'
              core_mem_we <= 1'b1;
              core_mem_addr <= j_idx;
              core_mem_wdata <= bf_out_a;
              sub_step <= 2'd3;
            end

            2'd3:
            begin // Write B'
              core_mem_we <= 1'b1;
              core_mem_addr <= j_idx + len;
              core_mem_wdata <= bf_out_b;

              // Loop Logic
              if (j_idx == start_idx + len - 1)
              begin
                // Group Done
                k_zeta <= k_zeta + 1; // Always increment

                if (32'(start_idx) + (32'(len) << 1) >= 256)
                begin
                  // Layer Done
                  if (mode == 1'b0)
                  begin
                    // NTT: len decreases
                    if (len == 2)
                    begin
                      state <= DONE;
                    end
                    else
                    begin
                      len <= len >> 1;
                      start_idx <= 8'd0;
                      j_idx <= 8'd0;
                    end
                  end
                  else
                  begin
                    // INTT: len increases
                    if (len == 128)
                    begin
                      state <= SCALING;
                      j_idx <= 8'd0; // Reuse j_idx for scaling
                      sub_step <= 2'd0;
                    end
                    else
                    begin
                      len <= len << 1;
                      start_idx <= 8'd0;
                      j_idx <= 8'd0;
                      // Update k for new len
                      // len << 1 means new len is 2*old_len.
                      // k_start = 128 / new_len.
                      k_zeta <= 7'(128 / (32'(len) << 1));
                    end
                  end
                end
                else
                begin
                  // Next Group
                  start_idx <= start_idx + (len << 1);
                  j_idx <= start_idx + (len << 1);
                end
              end
              else
              begin
                // Next J
                j_idx <= j_idx + 1;
              end

              if (state == LAYER)
                sub_step <= 2'd0;
            end
            default:
              sub_step <= 2'd0;
          endcase
        end

        SCALING:
        begin
          // Iterate 0..255 and multiply by scaling_factor
          case (sub_step)
            2'd0:
            begin
              bf_a <= mem[j_idx];
              bf_b <= 16'd0;
              current_zeta <= scaling_factor;
              sub_step <= 2'd1;
            end
            2'd1:
            begin
              // Wait for mul
              sub_step <= 2'd2;
            end
            2'd2:
            begin
              core_mem_we <= 1'b1;
              core_mem_addr <= j_idx;
              core_mem_wdata <= bf_out_b; // Result of Mul (since mode=1 from start)
              if (j_idx == 255)
              begin
                state <= DONE;
              end
              else
              begin
                j_idx <= j_idx + 1;
              end
              sub_step <= 2'd0;
            end
            default:
              sub_step <= 2'd0;
          endcase
        end

        DONE:
        begin
          done <= 1'b1;
          if (!start)
            state <= IDLE;
        end

        default:
          state <= IDLE;
      endcase
    end
  end

endmodule
