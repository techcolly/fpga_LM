// post_process.sv — per lane: ReLU, shift right 4, clamp to 0..127, turning 8 INT32 accumulators into 8 INT8 hidden values.

module post_process (
    input   logic[255:0] accumulator_word,

    output  logic[63:0]  hidden_word
);

genvar lane;

generate
    for (lane = 0; lane < 8; lane = lane + 1) begin : lanes
        logic[31:0] accumulator;
        logic[7:0]  hidden_byte;
        logic       negative, overflow;

        assign accumulator = accumulator_word[32*lane+31:32*lane];
        assign negative    = accumulator[31];
        assign overflow    = |accumulator[30:11];

        always_comb begin
            if (negative)      hidden_byte = 8'd0;
            else if (overflow) hidden_byte = 8'd127;
            else               hidden_byte = {1'b0, accumulator[10:4]};
        end

        assign hidden_word[8*lane+7:8*lane] = hidden_byte;
    end
endgenerate

endmodule
