// bias_rom.sv — 12 words of 8 INT32 biases (hidden layer words 0-3, output layer words 4-11); data is valid one clock after address.

module bias_rom #(
    parameter string INIT_FILE = "bias_rom.mem"
) (
    input   logic clk,
            logic[3:0] address,

    output  logic[255:0] data
);

logic[255:0] memory[12];

initial $readmemh(INIT_FILE, memory);

always_ff @(posedge clk) data <= memory[address];

endmodule
