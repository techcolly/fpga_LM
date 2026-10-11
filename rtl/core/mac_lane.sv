// mac_lane.sv — one signed INT8 x INT8 multiply-accumulate lane with an INT32 accumulator.

module mac_lane (
    input   logic clk, load_bias, accumulate_en,
            logic signed[7:0]  activation, weight,
            logic signed[31:0] bias,

    output  logic signed[31:0] accumulator
);

logic signed[15:0] product;

assign product = activation * weight;

always_ff @(posedge clk) begin
    if (load_bias)          accumulator <= bias;
    else if (accumulate_en) accumulator <= accumulator + product;
end

endmodule
