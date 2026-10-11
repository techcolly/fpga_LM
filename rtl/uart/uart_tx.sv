// uart_tx.sv — 8N1 serial transmitter; a one-clock send pulse (ignored while busy) sends data, least significant bit first.

module uart_tx #(
    parameter int CLOCKS_PER_BIT = 868
) (
    input   logic clk, reset, send,
            logic[7:0] data,

    output  logic tx, busy
);

localparam logic[1:0] IDLE  = 2'd0;
localparam logic[1:0] START = 2'd1;
localparam logic[1:0] DATA  = 2'd2;
localparam logic[1:0] STOP  = 2'd3;

logic[1:0]  state;
logic[15:0] clock_count;
logic[2:0]  bit_index;
logic[7:0]  shift_register;

assign busy = (state != IDLE);

always_ff @(posedge clk) begin
    if (reset) begin
        state       <= IDLE;
        tx          <= 1'b1;
        clock_count <= 16'd0;
        bit_index   <= 3'd0;
    end else begin
        case (state)
            IDLE: begin
                tx <= 1'b1;
                if (send) begin
                    shift_register <= data;
                    clock_count    <= 16'd0;
                    tx             <= 1'b0;
                    state          <= START;
                end
            end
            START: begin
                if (clock_count == CLOCKS_PER_BIT - 1) begin
                    clock_count <= 16'd0;
                    bit_index   <= 3'd0;
                    tx          <= shift_register[0];
                    state       <= DATA;
                end else begin
                    clock_count <= clock_count + 16'd1;
                end
            end
            DATA: begin
                if (clock_count == CLOCKS_PER_BIT - 1) begin
                    clock_count <= 16'd0;
                    if (bit_index == 3'd7) begin
                        tx    <= 1'b1;
                        state <= STOP;
                    end else begin
                        bit_index <= bit_index + 3'd1;
                        tx        <= shift_register[bit_index + 3'd1];
                    end
                end else begin
                    clock_count <= clock_count + 16'd1;
                end
            end
            STOP: begin
                if (clock_count == CLOCKS_PER_BIT - 1) state <= IDLE;
                else                                   clock_count <= clock_count + 16'd1;
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule
