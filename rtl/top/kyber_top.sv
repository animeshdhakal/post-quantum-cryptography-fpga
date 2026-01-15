module kyber_top (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [31:0] data_in,
    output logic [31:0] data_out,
    output logic        done
  );

  // Sponge Signals
  logic [4:0]  rate_words;
  logic        absorb_valid;
  logic [63:0] absorb_data;
  logic        absorb_ready;
  logic        absorb_last;
  logic        squeeze_valid;
  logic [63:0] squeeze_data;
  logic        squeeze_ready;
  logic        sponge_busy;

  // Instantiate Sponge
  keccak_sponge u_sponge (
                  .clk(clk),
                  .rst_n(rst_n),
                  .rate_words(rate_words),
                  .absorb_valid(absorb_valid),
                  .absorb_data(absorb_data),
                  .absorb_ready(absorb_ready),
                  .absorb_last(absorb_last),
                  .squeeze_valid(squeeze_valid),
                  .squeeze_data(squeeze_data),
                  .squeeze_ready(squeeze_ready),
                  .busy(sponge_busy)
                );

  // Hardcoded Config for Test (SHAKE128 rate = 1344 bits = 21 words)
  assign rate_words = 5'd21;

  // Simple State Machine for atomic test:
  // 1. Absorb 'data_in' (padded to 64-bit)
  // 2. Pad/Finish absorb
  // 3. Squeeze 32-bits
  typedef enum logic [2:0] {IDLE, ABSORB, PAD_WAIT, SQUEEZE, FINISH} state_t;
  state_t state, next_state;

  always_ff @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      state <= IDLE;
    end
    else
    begin
      state <= next_state;
    end
  end

  // Data Path & Control
  always_comb
  begin
    next_state = state;
    absorb_valid = 1'b0;
    absorb_last  = 1'b0;
    squeeze_ready = 1'b0;
    done = 1'b0;

    // Zero pad upper 32 bits
    absorb_data = {32'd0, data_in};

    case (state)
      IDLE:
      begin
        if (start)
          next_state = ABSORB;
      end

      ABSORB:
      begin
        if (absorb_ready)
        begin
          absorb_valid = 1'b1;
          absorb_last  = 1'b1; // Trigger permute after this word
          next_state = PAD_WAIT;
        end
      end

      PAD_WAIT:
      begin
        // Wait for sponge to switch to squeeze state (it might permute)
        if (squeeze_valid)
          next_state = SQUEEZE;
      end

      SQUEEZE:
      begin
        if (squeeze_valid)
        begin
          squeeze_ready = 1'b1; // Ack the read
          next_state = FINISH;
        end
      end

      FINISH:
      begin
        done = 1'b1;
        if (!start)
          next_state = IDLE;
      end

      default:
        next_state = IDLE;
    endcase
  end

  // Output mapping
  assign data_out = squeeze_data[31:0];

endmodule
