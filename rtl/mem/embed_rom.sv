// embed_rom.sv — 64 words of 8 INT8 embedding values, one word per token ID; data is valid one clock after address.

module embed_rom #(
    parameter string INIT_FILE = "embed_rom.mem"
) (
    input   logic clk,
            logic[5:0] address,

    output  logic[63:0] data
);

logic[63:0] memory[64];

initial $readmemh(INIT_FILE, memory);

always_ff @(posedge clk) data <= memory[address];

endmodule
