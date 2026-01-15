module keccak_sponge (
    input  logic        clk,
    input  logic        rst_n,

    // Configuration
    input  logic [4:0]  rate_words, // r/64. E.g. 21 for SHAKE128

    // Absorb Interface
    input  logic        absorb_valid,
    input  logic [63:0] absorb_data,
    output logic        absorb_ready,
    input  logic        absorb_last, // Indicates end of absorption -> Switch to Squeeze (permute if needed)

    // Squeeze Interface
    output logic        squeeze_valid,
    output logic [63:0] squeeze_data,
    input  logic        squeeze_ready,

    // Status
    output logic        busy
  );

  // Internal State
  logic [63:0] state [4:0][4:0];
  logic [63:0] next_state_in [4:0][4:0];
  logic [63:0] f1600_out [4:0][4:0];

  // F1600 Signals
  logic        f_start;
  logic        f_done;
  logic        f_busy;

  keccak_f1600 u_core (
                 .clk(clk),
                 .rst_n(rst_n),
                 .start(f_start),
                 .state_in(state),
                 .state_out(f1600_out),
                 .done(f_done),
                 .busy(f_busy)
               );

  // Sponge State Machine
  typedef enum logic [1:0] {IDLE, ABSORB, SQUEEZE, PERMUTE} state_t;
  state_t mode, return_mode; // return_mode stores where to go after PERMUTE

  logic [4:0] word_idx;       // 0 to 24 (lane index)
  logic [2:0] word_x, word_y; // coordinates derived from word_idx (FIXED: 3-bit width)

  // Coordinate mapping word_idx -> (x,y)
  // Map: 0->(0,0), 1->(1,0)... 4->(4,0), 5->(0,1)...
  assign word_x = 3'(word_idx % 5);
  assign word_y = 3'(word_idx / 5);

  always_ff @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      mode <= IDLE;
      word_idx <= 5'd0;
      return_mode <= IDLE;
      f_start <= 1'b0;
      // Clear state
      for(int i=0; i<5; i++)
        for(int j=0; j<5; j++)
          state[i][j] <= 64'd0;
    end
    else
    begin
      f_start <= 1'b0; // Default pulse

      case (mode)
        IDLE:
        begin
          // Clear state logic repeated if needed or rely on reset/clear signal?
          // For now, assume reset clears. Or Auto-clear?
          // Let's assume on IDLE we are ready to absorb.
          mode <= ABSORB;
          word_idx <= 5'd0;
        end

        ABSORB:
        begin
          if (absorb_valid)
          begin
            // XOR input with state
            state[word_x][word_y] <= state[word_x][word_y] ^ absorb_data;

            if (absorb_last)
            begin
              // End of input. MUST permute before squeezing?
              // Standard: Apply padding then permute?
              // If we assume software padded, we might need to permute IF we crossed a block or just to switch phases.
              // For simplicity: Always permute on transition to Squeeze.
              mode <= PERMUTE;
              return_mode <= SQUEEZE;
              f_start <= 1'b1;
              word_idx <= 5'd0;
            end
            else
            begin
              // Check if block full
              if (word_idx == rate_words - 1)
              begin
                // Block full, must permute
                mode <= PERMUTE;
                return_mode <= ABSORB;
                f_start <= 1'b1;
                word_idx <= 5'd0;
              end
              else
              begin
                word_idx <= word_idx + 1;
              end
            end
          end
        end

        PERMUTE:
        begin
          if (f_done)
          begin
            // Permutation finished. Update state.
            state <= f1600_out;
            mode <= return_mode;
          end
        end

        SQUEEZE:
        begin
          if (squeeze_ready)
          begin
            // Output data (done structurally via assign)

            // Check if we need more data (end of block)
            if (word_idx == rate_words - 1)
            begin
              // Block exhausted, permute to get more
              mode <= PERMUTE;
              return_mode <= SQUEEZE;
              f_start <= 1'b1;
              word_idx <= 5'd0;
            end
            else
            begin
              word_idx <= word_idx + 1;
            end
          end
        end
      endcase
    end
  end

  // Interface Logic
  assign absorb_ready = (mode == ABSORB) && !f_busy;
  assign squeeze_valid = (mode == SQUEEZE) && !f_busy;
  assign squeeze_data = state[word_x][word_y];

  assign busy = f_busy || (mode == PERMUTE);

endmodule
