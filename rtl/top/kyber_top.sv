module kyber_top (
    input  logic        clk,
    input  logic        rst_n,

    // Bus Interface
    input  logic        bus_write,
    input  logic        bus_enable,
    input  logic [31:0] bus_addr,
    input  logic [31:0] bus_wdata,
    output logic [31:0] bus_rdata,
    output logic        bus_ready
  );

  // =========================================================================
  // Signals Declaration (Moved up)
  // =========================================================================
  logic        core_busy;
  logic        sponge_busy;
  logic [1:0]  bus_wait_cnt; // Wait counter for Memory access
  // Sponge Interface Signals (Post MUX)
  logic [4:0]  sponge_rate;
  logic        sponge_absorb_valid;
  logic [63:0] sponge_absorb_data;
  logic        sponge_absorb_last;
  logic        sponge_squeeze_read;

  logic [63:0] sponge_squeeze_data;
  logic        sponge_squeeze_valid;
  logic        sponge_absorb_read;

  // =========================================================================
  // Sponge Control MUX (Bus vs Core)
  // =========================================================================

  // MUX Inputs (From Core)
  logic [4:0]  core_sponge_rate;
  logic        core_sponge_absorb_go;
  logic [63:0] core_sponge_absorb_data;
  logic        core_sponge_absorb_last;
  logic        core_sponge_squeeze_go;

  // MUX Inputs (From Bus)
  logic [4:0]  bus_sponge_rate_reg;
  logic        bus_sponge_absorb_go;
  logic [63:0] bus_sponge_absorb_data;
  logic        bus_sponge_absorb_last;
  logic        bus_sponge_squeeze_go;

  always_comb
  begin
    if (core_busy)
    begin
      // Core Controls Sponge
      sponge_rate         = core_sponge_rate;
      sponge_absorb_valid = core_sponge_absorb_go;
      sponge_absorb_data  = core_sponge_absorb_data;
      sponge_absorb_last  = core_sponge_absorb_last;
      sponge_squeeze_read = core_sponge_squeeze_go;
    end
    else
    begin
      // Bus Controls Sponge
      sponge_rate         = bus_sponge_rate_reg;
      sponge_absorb_valid = bus_sponge_absorb_go;
      sponge_absorb_data  = bus_sponge_absorb_data;
      sponge_absorb_last  = bus_sponge_absorb_last; // Fixed: Use Reg
      sponge_squeeze_read = bus_sponge_squeeze_go;
    end
  end

  // =========================================================================
  // Instantiate Sponge
  // =========================================================================

  keccak_sponge u_sponge (
                  .clk(clk),
                  .rst_n(rst_n),
                  .rate_words(sponge_rate),
                  .absorb_valid(sponge_absorb_valid),
                  .absorb_data(sponge_absorb_data),
                  .absorb_ready(sponge_absorb_read),
                  .absorb_last(sponge_absorb_last),
                  .squeeze_valid(sponge_squeeze_valid),
                  .squeeze_data(sponge_squeeze_data),
                  .squeeze_ready(sponge_squeeze_read),
                  .busy(sponge_busy)
                );

  // =========================================================================
  // Kyber Core Instantiation
  // =========================================================================
  logic        core_start;
  logic [3:0]  core_opcode;
  logic        core_done;
  // core_busy declared at top

  logic        core_mem_req;
  logic        core_mem_we;
  logic [15:0] core_mem_addr;
  logic [31:0] core_mem_wdata;
  logic [31:0] core_mem_rdata;

  // Map Bus to Core Memory Interface
  // Region 0x1000 - 0x1FFF maps to Core Memory
  always_comb
  begin
    core_mem_req   = 1'b0;
    core_mem_we    = 1'b0;
    core_mem_addr  = 16'd0;
    core_mem_wdata = 32'd0;

    if (bus_enable && (bus_addr[31:12] == 20'h001))
    begin // 0x1000 base
      core_mem_req   = 1'b1;
      core_mem_we    = bus_write;
      core_mem_addr  = bus_addr[15:0] - 16'h1000;
      core_mem_wdata = bus_wdata;
    end
  end

  kyber_core u_core (
               .clk(clk),
               .rst_n(rst_n),
               .cmd_start(core_start),
               .cmd_opcode(core_opcode),
               .cmd_done(core_done),
               .cmd_busy(core_busy),
               .mem_val(core_mem_req),
               .mem_we(core_mem_we),
               .mem_addr(core_mem_addr),
               .mem_wdata(core_mem_wdata),
               .mem_rdata(core_mem_rdata),

               .sponge_rate(core_sponge_rate),
               .sponge_absorb_go(core_sponge_absorb_go),
               .sponge_absorb_data(core_sponge_absorb_data),
               .sponge_absorb_read(sponge_absorb_read),
               .sponge_absorb_last(core_sponge_absorb_last),
               .sponge_squeeze_go(core_sponge_squeeze_go),
               .sponge_squeeze_valid(sponge_squeeze_valid),
               .sponge_squeeze_data(sponge_squeeze_data),
               .sponge_busy(sponge_busy)
             );

  // =========================================================================
  // Bus Slave Logic
  // =========================================================================

  always_ff @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      bus_rdata <= 32'd0;
      bus_ready <= 1'b0;

      bus_sponge_rate_reg <= 5'd21; // Default
      bus_sponge_absorb_data <= 64'd0;
      bus_sponge_absorb_go <= 1'b0;
      bus_sponge_absorb_last <= 1'b0;
      bus_sponge_squeeze_go <= 1'b0;

      core_start <= 1'b0;
      core_opcode <= 4'd0;
    end
    else
    begin
      // Autoclear pulses
      bus_ready <= 1'b0;
      bus_sponge_absorb_go <= 1'b0;
      bus_sponge_squeeze_go <= 1'b0;
      core_start <= 1'b0;

      if (bus_enable && !bus_ready)
      begin
        if (bus_write)
        begin
          // Write: Immediate Ready
          bus_ready <= 1'b1;
          bus_wait_cnt <= 2'd0; // Reset wait counter on write

          if (bus_addr == 32'h0004)
          begin
            if (bus_wdata[1])
              bus_sponge_absorb_last <= 1;
            else
              bus_sponge_absorb_last <= 0;
          end
          else if (bus_addr == 32'h0010)
          begin
            bus_sponge_rate_reg <= bus_wdata[4:0];
          end
          else if (bus_addr == 32'h0014)
          begin
            bus_sponge_absorb_data <= {32'd0, bus_wdata};
            bus_sponge_absorb_go <= 1'b1;
          end
          else if (bus_addr == 32'h0020)
          begin
            if (bus_wdata[0])
              core_start <= 1'b1;
            core_opcode <= bus_wdata[4:1];
          end
        end
        else
        begin
          // Read
          if (bus_addr[31:12] == 20'h001)
          begin
            // Memory Read (High Latency)
            if (bus_wait_cnt < 2'd2)
            begin
              bus_wait_cnt <= bus_wait_cnt + 2'd1;
            end
            else
            begin
              bus_wait_cnt <= 2'd0;
              bus_ready <= 1'b1;
              bus_rdata <= core_mem_rdata;
            end
          end
          else
          begin
            // Register Read
            bus_ready <= 1'b1;
            bus_wait_cnt <= 2'd0;

            case (bus_addr)
              32'h0000:
                bus_rdata <= {28'd0, sponge_squeeze_valid, sponge_absorb_read, core_busy, sponge_busy};
              32'h0010:
                bus_rdata <= {27'd0, bus_sponge_rate_reg};
              32'h0014:
              begin
                bus_rdata <= sponge_squeeze_data[31:0];
                if (sponge_squeeze_valid)
                  bus_sponge_squeeze_go <= 1'b1;
              end
              default:
                bus_rdata <= 32'd0;
            endcase
          end
        end
      end
      else
      begin
        bus_wait_cnt <= 2'd0; // Reset wait counter if bus not enabled or ready is already high
      end
    end
  end

endmodule
