module kyber_top (
    input  logic        clk,
    input  logic        rst_n,

    // Bus Interface (Simple 32-bit)
    input  logic        bus_write,  // 1 = Write, 0 = Read
    input  logic        bus_enable, // Chip Select / Valid
    input  logic [31:0] bus_addr,
    input  logic [31:0] bus_wdata,
    output logic [31:0] bus_rdata,
    output logic        bus_ready   // Ack
  );

  // =========================================================================
  // Address Map
  // =========================================================================
  // 0x0000: Status (R)
  //         [0] Sponge Busy
  //         [1] NTT Busy
  //         [2] Sponge Absorb Ready
  //         [3] Sponge Squeeze Valid
  //
  // 0x0004: Sponge Start/Control (W)
  //         [0] reserved
  //         [1] Absorb Last (Trigger Permute if needed)
  //
  // 0x0010: Sponge Rate Config (RW)
  //
  // 0x0014: Sponge Data Port (RW)
  //         Write -> Absorb Data (low 32 bits, padded)
  //         Read  -> Squeeze Data (low 32 bits)
  //
  // 0x0020: NTT Control (W)
  //         [0] Start NTT
  //
  // 0x1000 - 0x13FF: NTT Memory (256 words, 4 byte stride for 32-bit aligned access)
  //                  Addr = 0x1000 + (idx * 4)

  // =========================================================================
  // Signals
  // =========================================================================

  // Sponge
  logic [4:0]  sponge_rate;
  logic        sponge_absorb_valid;
  logic [63:0] sponge_absorb_data;
  logic        sponge_absorb_read; // Handshake from sponge
  logic        sponge_absorb_last;
  logic        sponge_squeeze_read; // Handshake to sponge
  logic        sponge_squeeze_valid;
  logic [63:0] sponge_squeeze_data;
  logic        sponge_busy;

  // NTT
  logic        ntt_start;
  logic        ntt_mode;
  logic        ntt_done;
  logic        ntt_busy;

  // NTT Memory Interface (Controlled by Bus AND NTT Core)
  // We need an arbiter or mux.
  // Bus has priority or interleaved?
  // User should not access memory while NTT is running.
  // Simple Mux: If NTT Busy, Bus locked out of memory.

  logic        ntt_mem_we_core;
  logic [7:0]  ntt_mem_addr_core; // 0..255
  logic [15:0] ntt_mem_wdata_core;
  logic [7:0]  ntt_mem_raddr_core; // read addr
  logic [15:0] ntt_mem_rdata_core; // data to core

  logic        ntt_mem_we_bus;
  logic [7:0]  ntt_mem_addr_bus;
  logic [15:0] ntt_mem_wdata_bus;
  logic [15:0] ntt_mem_rdata_bus; // data to bus

  // Actual RAM Signals
  logic        ram_we;
  logic [7:0]  ram_addr; // Single port for now? Or dual port?
  // The NTT Core I wrote:
  //   input  logic        mem_wr_en,
  //   input  logic [7:0]  mem_wr_addr,
  //   input  logic [15:0] mem_wr_data,
  //   input  logic [7:0]  mem_rd_addr,
  //   output logic [15:0] mem_rd_data,
  // Providing dual ports interfaces.
  // So let's instantiate the RAM internally inside NTT Core?
  // Or keep it outside?
  // My previous NTT core has "Internal Memory: 256 x 16 logic [15:0] mem [255:0];"
  // And it has an external write port.
  // It EXPOSES a read port.
  // But does it allow external reads?
  // "assign mem_rd_data = mem[mem_rd_addr];" -> Yes, async read.
  // But it ALSO uses the memory internally.
  // "mem[j_idx]" ...
  // The code I wrote for NTT Core:
  // "if (mem_wr_en) mem[mem_wr_addr] <= mem_wr_data;"
  // AND
  // "case(state)... mem[j_idx] <= ..."
  // This implies Multi-Driver on 'mem'. SystemVerilog allows this for variables if not checking contention?
  // NO, 'logic' cannot be driven by two always blocks.
  // I need to fix NTT Core to mux the write port.

  // =========================================================================
  // Instantiate Sponge
  // =========================================================================

  // Pulse generation for handshake
  logic sponge_absorb_go;
  logic sponge_squeeze_go;

  always_comb
  begin
    sponge_absorb_valid = sponge_absorb_go;
    sponge_squeeze_read = sponge_squeeze_go;
  end

  keccak_sponge u_sponge (
                  .clk(clk),
                  .rst_n(rst_n),
                  .rate_words(sponge_rate),
                  .absorb_valid(sponge_absorb_valid),
                  .absorb_data(sponge_absorb_data),
                  .absorb_ready(sponge_absorb_read), // output from sponge
                  .absorb_last(sponge_absorb_last),
                  .squeeze_valid(sponge_squeeze_valid),
                  .squeeze_data(sponge_squeeze_data),
                  .squeeze_ready(sponge_squeeze_read), // input to sponge
                  .busy(sponge_busy)
                );

  // =========================================================================
  // Instantiate NTT Core
  // =========================================================================

  // We need to MUX the memory inputs to the NTT core.
  logic        mux_mem_we;
  logic [7:0]  mux_mem_waddr;
  logic [15:0] mux_mem_wdata;
  logic [7:0]  mux_mem_raddr;
  logic [15:0] mux_mem_rdata; // Output from core

  assign ntt_mem_rdata_bus = mux_mem_rdata;

  // Bus access logic for NTT
  assign ntt_mem_we_bus = (bus_enable && bus_write && (bus_addr[31:12] == 20'h001)) ? 1'b1 : 1'b0;
  assign ntt_mem_addr_bus = bus_addr[9:2]; // stride 4
  assign ntt_mem_wdata_bus = bus_wdata[15:0];

  // Since I implemented the NTT Core with internal memory and an external write port,
  // I should probably use that external port for the BUS.
  // AND the NTT Core logic assumes it owns the memory internally.
  // BUT the NTT Core logic in my previous step had:
  // "case(state) ... mem[j_idx] <= ..."
  // AND "if(mem_wr_en) mem[mem_wr_addr] <= ..."
  // This is a conflict if not muxed carefully or handled by port logic.
  // Ideally, I should pass `bus` signals INTO the NTT core and let it MUX internally using `mem_wr_en`.
  // My previous NTT core code:
  // always_ff ... if (mem_wr_en) ... else case(state) ...
  // The `if` was outside the case. So it has priority or runs in parallel?
  // It was:
  // if (mem_wr_en) mem <= ...
  // case(state) ... mem[j] <= ...
  // This is valid if they don't fire same cycle.
  // If NTT is BUSY, we shouldn't write from Bus.

  ntt_core u_ntt (
             .clk(clk),
             .rst_n(rst_n),
             .start(ntt_start),
             .mode(ntt_mode),
             .mem_wr_en(ntt_mem_we_bus), // Bus writes
             .mem_wr_addr(ntt_mem_addr_bus),
             .mem_wr_data(ntt_mem_wdata_bus),
             .mem_rd_addr(ntt_mem_addr_bus), // Bus reads (mapped to same addr port for now)
             .mem_rd_data(mux_mem_rdata),
             .done(ntt_done),
             .busy(ntt_busy)
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
      sponge_rate <= 5'd21; // Default
      sponge_absorb_data <= 64'd0;
      sponge_absorb_go <= 1'b0;
      sponge_absorb_last <= 1'b0;
      sponge_squeeze_go <= 1'b0;
      ntt_start <= 1'b0;
    end
    else
    begin
      // Autoclear pulses
      bus_ready <= 1'b0;
      sponge_absorb_go <= 1'b0;
      sponge_squeeze_go <= 1'b0; // Auto clear
      ntt_start <= 1'b0;

      if (bus_enable && !bus_ready)
      begin
        bus_ready <= 1'b1; // Single cycle ack for now

        if (bus_write)
        begin
          // Write
          if (bus_addr == 32'h0004)
          begin
            // Control/Config
            if (bus_wdata[1])
              sponge_absorb_last <= 1;
            else
              sponge_absorb_last <= 0;
          end
          else if (bus_addr == 32'h0010)
          begin
            sponge_rate <= bus_wdata[4:0];
          end
          else if (bus_addr == 32'h0014)
          begin
            sponge_absorb_data <= {32'd0, bus_wdata}; // Lower 32 only
            sponge_absorb_go <= 1'b1; // Trigger absorb
          end
          else if (bus_addr == 32'h0020)
          begin
            if (bus_wdata[0])
              ntt_start <= 1'b1;
            ntt_mode <= bus_wdata[1];
          end
          // NTT Memory Writes handled directly by instance wiring above
        end
        else
        begin
          // Read
          case (bus_addr)
            32'h0000:
            begin
              bus_rdata <= {28'd0, sponge_squeeze_valid, sponge_absorb_read, ntt_busy, sponge_busy};
            end
            32'h0010:
              bus_rdata <= {27'd0, sponge_rate};
            32'h0014:
            begin
              // Read from Sponge Squeeze
              // If Valid, return data and Ack
              // Note: Triggering "read accept" on the read cycle.
              // We need to latch data? Squeeze data is valid while squeeze_valid is high.
              bus_rdata <= sponge_squeeze_data[31:0];
              if (sponge_squeeze_valid)
                sponge_squeeze_go <= 1'b1; // Pop
            end
            default:
            begin
              // Check Ranges
              // NTT Memory 0x1000 range
              if (bus_addr[31:12] == 20'h001)
              begin
                bus_rdata <= {16'd0, mux_mem_rdata};
              end
              else
              begin
                bus_rdata <= 32'd0;
              end
            end
          endcase
        end
      end
    end
  end

endmodule
