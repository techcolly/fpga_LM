// argmax.sv — running maximum of the 64 output logits, fed one lane per cycle; strict compare keeps the lowest index on ties.

module argmax (
    input   logic clk, compare_en, argmax_clear,
            logic[255:0] accumulator_word,
            logic[2:0]   group_index, lane_index,

    output  logic signed[31:0] best_value,
            logic[5:0]         best_index
);

logic signed[31:0] logit;

assign logit = accumulator_word[32*lane_index +: 32];

always_ff @(posedge clk) begin
    if (argmax_clear) begin
        best_value <= 32'sh80000000;
        best_index <= 6'd0;
    end else if (compare_en && logit > best_value) begin
        best_value <= logit;
        best_index <= {group_index, lane_index};
    end
end

endmodule
