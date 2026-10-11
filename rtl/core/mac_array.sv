// mac_array.sv — eight mac_lane instances sharing one registered activation; lane i uses weight byte i and bias word i, and the weight must arrive one clock after its activation.

module mac_array (
    input   logic clk, load_bias, accumulate_en,
            logic signed[7:0] activation,
            logic[63:0]       weight_word,
            logic[255:0]      bias_word,

    output  logic[255:0] accumulator_word
);

logic signed[7:0] activation_reg;

always_ff @(posedge clk) activation_reg <= activation;

genvar lane;

generate
    for (lane = 0; lane < 8; lane = lane + 1) begin : lanes
        mac_lane lane_unit (
            .clk           (clk),
            .load_bias     (load_bias),
            .accumulate_en (accumulate_en),
            .activation    (activation_reg),
            .weight        (weight_word[8*lane+7:8*lane]),
            .bias          (bias_word[32*lane+31:32*lane]),
            .accumulator   (accumulator_word[32*lane+31:32*lane])
        );
    end
endgenerate

endmodule
