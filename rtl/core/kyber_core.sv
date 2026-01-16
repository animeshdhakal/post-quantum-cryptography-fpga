module kyber_core (
    input  logic        clk,
    input  logic        rst_n,

    // Command Interface
    input  logic        cmd_start,
    input  logic [3:0]  cmd_opcode,
    output logic        cmd_done,
    output logic        cmd_busy,

    // Bus Interface
    input  logic        mem_val,
    input  logic        mem_we,
    input  logic [15:0] mem_addr,
    input  logic [31:0] mem_wdata,
    output logic [31:0] mem_rdata,

    // Sponge Interface
    output logic [4:0]  sponge_rate,
    output logic        sponge_absorb_go,
    output logic [63:0] sponge_absorb_data,
    input  logic        sponge_absorb_read,
    output logic        sponge_absorb_last,
    output logic        sponge_squeeze_go,
    input  logic        sponge_squeeze_valid,
    input  logic [63:0] sponge_squeeze_data,
    input  logic        sponge_busy
  );

  // =========================================================================
  // FSM State Declaration
  // =========================================================================
  typedef enum logic [4:0] {
            IDLE,

            // GenKey Steps
            GEN_S,
            GEN_E,
            GEN_A,

            // NTT Transfer Steps
            LOAD_NTT,       // Address Setup
            LOAD_NTT_WR0,   // Write Low 16
            LOAD_NTT_WR1,   // Write High 16

            RUN_NTT,

            UNLOAD_NTT_RD0, // Read Low Setup
            UNLOAD_NTT_RD1, // Read High Setup + Latch Low
            UNLOAD_NTT_WR,  // Write 32-bit to RAM

            // MulAcc Steps
            M0, M1, M2, M3, M4, M5,

            DONE
          } state_t;
  state_t state;

  logic [8:0]  i_cnt;
  logic [8:0]  base_addr;

  // Registers for Data Transfer
  logic [15:0] temp_data_low;

  // =========================================================================
  // PolyRAM (2KB)
  // =========================================================================
  logic [31:0] poly_ram [0:511];

  logic [3:0]  ram_we_core;
  logic [8:0]  ram_addr_core; // Driver
  logic [31:0] ram_wdata_core;
  logic [31:0] ram_rdata_core;

  logic [3:0]  ram_we_bus;
  logic [8:0]  ram_addr_bus;
  logic [31:0] ram_wdata_bus;
  logic [31:0] ram_rdata_bus;

  logic [3:0]  ram_we_cbd;
  logic [8:0]  ram_addr_cbd;
  logic [31:0] ram_wdata_cbd;

  logic [3:0]  mux_we;
  logic [8:0]  mux_addr;
  logic [31:0] mux_wdata;

  assign ram_we_bus    = (mem_val && mem_we) ? 4'b1111 : 4'b0000;
  assign ram_addr_bus  = mem_addr[10:2];
  assign ram_wdata_bus = mem_wdata;

  assign ram_we_cbd    = cbd_valid ? 4'b1111 : 4'b0000;
  assign ram_wdata_cbd = cbd_out_data;
  assign ram_addr_cbd  = cbd_write_addr_ptr;

  always_comb
  begin
    if (state == GEN_S || state == GEN_E)
    begin
      mux_we    = ram_we_cbd;
      mux_addr  = ram_addr_cbd;
      mux_wdata = ram_wdata_cbd;
    end
    else if (cmd_busy)
    begin
      mux_we    = ram_we_core;
      mux_addr  = ram_addr_core;
      mux_wdata = ram_wdata_core;
    end
    else
    begin
      mux_we    = ram_we_bus;
      mux_addr  = ram_addr_bus;
      mux_wdata = ram_wdata_bus;
    end
  end

  always_ff @(posedge clk)
  begin
    if (mux_we[0])
      poly_ram[mux_addr][7:0]   <= mux_wdata[7:0];
    if (mux_we[1])
      poly_ram[mux_addr][15:8]  <= mux_wdata[15:8];
    if (mux_we[2])
      poly_ram[mux_addr][23:16] <= mux_wdata[23:16];
    if (mux_we[3])
      poly_ram[mux_addr][31:24] <= mux_wdata[31:24];

    if (mux_we == 4'b0000)
    begin
      ram_rdata_bus  <= poly_ram[ram_addr_bus];
      ram_rdata_core <= poly_ram[ram_addr_core];
    end
  end
  assign mem_rdata = ram_rdata_bus;

  // Lint Suppression
  logic _unused_ok;
  assign _unused_ok = &{1'b0, sponge_absorb_read, sponge_busy};

  // =========================================================================
  // NTT Core Integration
  // =========================================================================
  logic        ntt_start;
  logic        ntt_mode;
  logic        ntt_done;
  logic        ntt_busy_internal;

  logic        ntt_copy_we;
  logic [7:0]  ntt_copy_wr_addr;
  logic [15:0] ntt_copy_wr_data;
  logic [7:0]  ntt_copy_rd_addr;
  logic [15:0] ntt_copy_rd_data;

  ntt_core u_ntt (
             .clk(clk),
             .rst_n(rst_n),
             .start(ntt_start),
             .mode(ntt_mode),
             .mem_wr_en(ntt_copy_we),
             .mem_wr_addr(ntt_copy_wr_addr),
             .mem_wr_data(ntt_copy_wr_data),
             .mem_rd_addr(ntt_copy_rd_addr),
             .mem_rd_data(ntt_copy_rd_data),
             .done(ntt_done),
             .busy(ntt_busy_internal)
           );

  // =========================================================================
  // CBD
  // =========================================================================
  logic        cbd_start;
  logic [63:0] cbd_in_data;
  logic [31:0] cbd_out_data;
  logic        cbd_valid;
  logic        cbd_done;
  logic [8:0]  cbd_write_addr_ptr;

  cbd u_cbd (
        .clk(clk),
        .rst_n(rst_n),
        .start(cbd_start),
        .in_data(cbd_in_data),
        .out_data(cbd_out_data),
        .valid(cbd_valid),
        .done(cbd_done)
      );

  // Math Units
  logic signed [15:0] mul_a0, mul_b0, mul_out0;
  logic signed [15:0] mul_a1, mul_b1, mul_out1;
  ntt_mul u_mul0 (.a(mul_a0), .b(mul_b0), .out(mul_out0));
  ntt_mul u_mul1 (.a(mul_a1), .b(mul_b1), .out(mul_out1));

  function automatic logic [15:0] mod_add(input logic [15:0] a, input logic [15:0] b);
    logic [16:0] sum;
    sum = {1'b0, a} + {1'b0, b};
    if (sum >= 17'd3329)
      sum = sum - 17'd3329;
    return sum[15:0];
  endfunction

  logic [31:0] reg_s, reg_a, reg_e;
  always_comb
  begin
    mul_a0 = signed'(reg_s[15:0]);
    mul_b0 = signed'(reg_a[15:0]);
    mul_a1 = signed'(reg_s[31:16]);
    mul_b1 = signed'(reg_a[31:16]);
  end

  assign sponge_rate = 5'd21;
  assign sponge_absorb_go = 0;
  assign sponge_absorb_data = 0;
  assign sponge_absorb_last = 0;
  assign sponge_squeeze_go = (state == GEN_A || state == GEN_S || state == GEN_E || state == GEN_A) && !sponge_busy && !cbd_valid;
  assign cbd_in_data = sponge_squeeze_data;
  assign cbd_start   = sponge_squeeze_valid && (state == GEN_S || state == GEN_E);

  // FSM Address Logic
  always_comb
  begin
    ram_addr_core = 9'd0;
    if (state == LOAD_NTT)
      ram_addr_core = base_addr + i_cnt;
    else if (state == UNLOAD_NTT_WR)
      ram_addr_core = base_addr + i_cnt;
    else if (state == M0)
      ram_addr_core = i_cnt;
    else if (state == M1)
      ram_addr_core = 9'd128 + i_cnt;
    else if (state == M2 || state == M3)
      ram_addr_core = 9'd256 + i_cnt;
    else if (state == M4 || state == M5)
      ram_addr_core = 9'd384 + i_cnt; // T
    else if (state == GEN_A)
      ram_addr_core = 9'd128 + i_cnt;
  end

  logic [1:0] next_ntt_target; // 0=A, 1=S, 2=E

  always_ff @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      state <= IDLE;
      ntt_start <= 0;
      cmd_busy <= 0;
      cmd_done <= 0;
      ram_we_core <= 4'b0000;
      ram_wdata_core <= 0;
      i_cnt <= 0;
      cbd_write_addr_ptr <= 0;
      ntt_copy_we <= 0;
      ntt_copy_wr_addr <= 0;
      ntt_copy_wr_data <= 0;
      ntt_copy_rd_addr <= 0;
      base_addr <= 0;
      next_ntt_target <= 0;
      temp_data_low <= 0;
    end
    else
    begin
      cmd_done <= 0;
      ram_we_core <= 4'b0000;
      ntt_start <= 0;
      ntt_copy_we <= 0;

      case (state)
        IDLE:
        begin
          cmd_busy <= 0;
          if (cmd_start)
          begin
            cmd_busy <= 1;
            if (cmd_opcode == 4'd8 || cmd_opcode == 4'd9)
            begin
              base_addr <= 0;
              ntt_mode <= (cmd_opcode == 4'd9);
              i_cnt <= 0;
              state <= LOAD_NTT;
            end
            else if (cmd_opcode == 4'd10)
            begin
              i_cnt <= 0;
              state <= M0;
            end
            else if (cmd_opcode == 4'd1)
            begin
              state <= GEN_A;
              i_cnt <= 0;
              next_ntt_target <= 0;
            end
            else
            begin
              state <= DONE;
            end
          end
        end

        GEN_A:
        begin
          // Squeeze A directly from Sponge to RAM (Address 128)
          if (sponge_squeeze_valid)
          begin
            ram_we_core <= 4'b1111;
            // ram_addr_core driven by Comb
            // Reduce modulo 3329
            ram_wdata_core[15:0]  <= sponge_squeeze_data[15:0] < 16'd3329 ? sponge_squeeze_data[15:0] : (sponge_squeeze_data[15:0] % 16'd3329);
            ram_wdata_core[31:16] <= sponge_squeeze_data[31:16] < 16'd3329 ? sponge_squeeze_data[31:16] : (sponge_squeeze_data[31:16] % 16'd3329);

            if (i_cnt == 9'd127)
            begin
              state <= LOAD_NTT;
              base_addr <= 9'd128; // A
              i_cnt <= 0;
              ntt_mode <= 0;
            end
            else
              i_cnt <= i_cnt + 1;
          end
        end

        GEN_S:
        begin
          if (cbd_valid && cbd_write_addr_ptr < 9'd128)
            cbd_write_addr_ptr <= cbd_write_addr_ptr + 1;
          if (cbd_write_addr_ptr >= 9'd128)
          begin
            state <= GEN_E;
            cbd_write_addr_ptr <= 9'd256;
          end
        end
        GEN_E:
        begin
          if (cbd_valid && cbd_write_addr_ptr < 9'd384)
            cbd_write_addr_ptr <= cbd_write_addr_ptr + 1;
          if (cbd_write_addr_ptr >= 9'd384)
          begin
            state <= LOAD_NTT;
            base_addr <= 9'd0; // S
            ntt_mode <= 0;
            i_cnt <= 0;
            next_ntt_target <= 0;
          end
        end

        LOAD_NTT:
        begin
          state <= LOAD_NTT_WR0;
        end
        LOAD_NTT_WR0:
        begin
          ntt_copy_we <= 1;
          ntt_copy_wr_addr <= {i_cnt[6:0], 1'b0}; // Even (0, 2, 4...)
          ntt_copy_wr_data <= ram_rdata_core[15:0];
          state <= LOAD_NTT_WR1;
        end
        LOAD_NTT_WR1:
        begin
          ntt_copy_we <= 1;
          ntt_copy_wr_addr <= {i_cnt[6:0], 1'b1}; // Odd (1, 3, 5...)
          ntt_copy_wr_data <= ram_rdata_core[31:16];

          if (i_cnt == 9'd127)
          begin
            state <= RUN_NTT;
            ntt_start <= 1;
          end
          else
          begin
            i_cnt <= i_cnt + 1;
            state <= LOAD_NTT;
          end
        end

        RUN_NTT:
        begin
          if (ntt_done)
          begin
            state <= UNLOAD_NTT_RD0;
            i_cnt <= 0;
            ntt_copy_rd_addr <= 0;
          end
        end

        UNLOAD_NTT_RD0:
        begin
          ntt_copy_rd_addr <= {i_cnt[6:0], 1'b0}; // Even
          state <= UNLOAD_NTT_RD1;
        end
        UNLOAD_NTT_RD1:
        begin
          // Read Data Valid from RD0 (Async/Internal)
          temp_data_low <= ntt_copy_rd_data;
          ntt_copy_rd_addr <= {i_cnt[6:0], 1'b1}; // Odd
          state <= UNLOAD_NTT_WR;
        end
        UNLOAD_NTT_WR:
        begin
          // Read Data Valid from RD1
          ram_wdata_core <= {ntt_copy_rd_data, temp_data_low};
          ram_we_core <= 4'b1111;

          if (i_cnt == 9'd127)
          begin
            if (cmd_opcode == 4'd1 && base_addr == 9'd128)
            begin
              // Done NTT(A). Start GEN_S.
              state <= GEN_S;
              cbd_write_addr_ptr <= 9'd0;
              next_ntt_target <= 1; // Mark S next?
              // Actually we rely on GEN_S -> ... -> NTT(S) flow which sets checks.
            end
            else if (cmd_opcode == 4'd1 && base_addr == 9'd0)
            begin
              // Done NTT(S). Start NTT(E).
              state <= LOAD_NTT;
              base_addr <= 9'd256; // E
              i_cnt <= 0;
              ntt_start <= 0;
            end
            else if (cmd_opcode == 4'd1 && base_addr == 9'd256)
            begin
              // Done NTT(E). Start MulAcc.
              state <= M0;
              i_cnt <= 0;
            end
            else
            begin
              state <= DONE; // Direct NTT/INTT command
            end
          end
          else
          begin
            i_cnt <= i_cnt + 1;
            state <= UNLOAD_NTT_RD0;
          end
        end

        M0:
        begin
          state <= M1;
        end
        M1:
        begin
          reg_s <= ram_rdata_core;
          state <= M2;
        end
        M2:
        begin
          reg_a <= ram_rdata_core;
          state <= M3;
        end
        M3:
        begin
          reg_e <= ram_rdata_core;
          state <= M4;
        end
        M4:
        begin
          ram_wdata_core[15:0]  <= mod_add(mul_out0, reg_e[15:0]);
          ram_wdata_core[31:16] <= mod_add(mul_out1, reg_e[31:16]);
          ram_we_core <= 4'b1111;
          state <= M5;
        end
        M5:
        begin
          if (i_cnt == 9'd127)
            state <= DONE;
          else
          begin
            i_cnt <= i_cnt + 9'd1;
            state <= M0;
          end
        end

        DONE:
        begin
          cmd_busy <= 0;
          cmd_done <= 1;
          state <= IDLE;
        end

        default:
          state <= IDLE;
      endcase
    end
  end

endmodule
