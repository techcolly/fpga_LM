// input_vector.sv — 32 INT8 inputs stored as four 64-bit token embeddings; read one byte at a time with no clock delay.
// This is scratch space rewritten every inference, not weights; the weights are in weight_rom and the embedding table is embed_rom.

module input_vector (
    input   logic clk, input_vector_we,
            logic[1:0]  token_index,
            logic[4:0]  input_index,
            logic[63:0] embed_data,

    output  logic signed[7:0] input_activation
);

logic[255:0] storage;

always_ff @(posedge clk) begin
    if (input_vector_we) storage[64*token_index +: 64] <= embed_data;
end

assign input_activation = storage[8*input_index +: 8];

endmodule
