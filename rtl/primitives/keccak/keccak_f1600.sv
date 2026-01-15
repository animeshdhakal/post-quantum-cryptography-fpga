module keccak_f1600 (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [63:0] state_in [4:0][4:0],
    output logic [63:0] state_out[4:0][4:0],
    output logic        done,
    output logic        busy
);

    logic [4:0] round_ctr;
    logic [63:0] round_in [4:0][4:0];
    logic [63:0] round_out[4:0][4:0];
    logic        round_active;

    // Instantiate combinatorial round logic
    keccak_round u_round (
        .round_idx (round_ctr),
        .state_in  (round_in),
        .state_out (round_out)
    );

    // State Machine / Counters
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            round_ctr <= 5'd0;
            round_active <= 1'b0;
            done <= 1'b0;
            // Reset state storage
            for(int x=0; x<5; x++)
                for(int y=0; y<5; y++)
                    state_out[x][y] <= 64'd0;
        end else begin
            done <= 1'b0; // Default

            if (start && !round_active) begin
                // Load state
                state_out <= state_in;
                round_ctr <= 5'd0;
                round_active <= 1'b1;
            end else if (round_active) begin
                // Capture round output
                state_out <= round_out;

                if (round_ctr == 5'd23) begin
                    // Finished 24 rounds
                    round_active <= 1'b0;
                    done <= 1'b1;
                    round_ctr <= 5'd0;
                end else begin
                    round_ctr <= round_ctr + 1;
                end
            end
        end
    end

    // Input to the combinatorial round logic
    // If just starting (cycle 0 of active), we could technically mux state_in here,
    // but we loaded it into state_out register on 'start', so we use state_out.
    assign round_in = state_out;
    assign busy = round_active;

endmodule
