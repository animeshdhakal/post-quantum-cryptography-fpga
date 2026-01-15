module kyber_top (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [31:0] data_in,
    output logic [31:0] data_out,
    output logic        done
);

    // Keccak Signals
    logic [63:0] keccak_state_in [4:0][4:0];
    logic [63:0] keccak_state_out[4:0][4:0];
    logic        keccak_start;
    logic        keccak_done;
    logic        keccak_busy;

    // Instantiate Keccak Core
    keccak_f1600 u_keccak (
        .clk(clk),
        .rst_n(rst_n),
        .start(keccak_start),
        .state_in(keccak_state_in),
        .state_out(keccak_state_out),
        .done(keccak_done),
        .busy(keccak_busy)
    );

    // Simple Control Logic
    typedef enum logic [1:0] {IDLE, WAIT_DONE, FINISH} state_t;
    state_t state, next_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            keccak_start <= 1'b0;
        end else begin
            state <= next_state;
            keccak_start <= (state == IDLE && start);
        end
    end

    // Data datapath
    always_comb begin
        // default
        for(int x=0; x<5; x++)
            for(int y=0; y<5; y++)
                keccak_state_in[x][y] = 64'd0;

        // Load input data into first lane (simple test wrapper - lower 32 bits)
        keccak_state_in[0][0] = {32'd0, data_in};
    end

    // Read output from first lane
    assign data_out = keccak_state_out[0][0][31:0];

    // State Machine
    always_comb begin
        next_state = state;
        done = 1'b0;

        case (state)
            IDLE: begin
                if (start) next_state = WAIT_DONE;
            end
            WAIT_DONE: begin
                if (keccak_done) next_state = FINISH;
            end
            FINISH: begin
                done = 1'b1;
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule
