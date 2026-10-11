// uart_rx.sv — 8N1 serial receiver; samples each bit mid-bit and pulses data_valid for one clock when a good frame arrives.

module uart_rx #(
    parameter int CLOCKS_PER_BIT = 868
) (
    input   logic clk, reset, rx,

    output  logic[7:0] data,
            logic      data_valid
);

localparam logic[1:0] IDLE  = 2'd0;
localparam logic[1:0] START = 2'd1;
localparam logic[1:0] DATA  = 2'd2;
localparam logic[1:0] STOP  = 2'd3;

logic[1:0]  state;
logic[15:0] clock_count;
logic[2:0]  bit_index;
logic[7:0]  shift_register;
logic       rx_meta, rx_sync;

always_ff @(posedge clk) begin
    rx_meta <= rx;
    rx_sync <= rx_meta;
end

always_ff @(posedge clk) begin
    data_valid <= 1'b0;

    if (reset) begin
        state       <= IDLE;
        clock_count <= 16'd0;
        bit_index   <= 3'd0;
    end else begin
        case (state)
            IDLE: begin
                clock_count <= 16'd0;
                bit_index   <= 3'd0;
                if (!rx_sync) state <= START;
            end
            START: begin
                if (clock_count == CLOCKS_PER_BIT / 2 - 1) begin
                    clock_count <= 16'd0;
                    if (!rx_sync) state <= DATA;
                    else          state <= IDLE;
                end else begin
                    clock_count <= clock_count + 16'd1;
                end
            end
            DATA: begin
                if (clock_count == CLOCKS_PER_BIT - 1) begin
                    clock_count               <= 16'd0;
                    shift_register[bit_index] <= rx_sync;
                    if (bit_index == 3'd7) state     <= STOP;
                    else                   bit_index <= bit_index + 3'd1;
                end else begin
                    clock_count <= clock_count + 16'd1;
                end
            end
            STOP: begin
                if (clock_count == CLOCKS_PER_BIT - 1) begin
                    clock_count <= 16'd0;
                    state       <= IDLE;
                    if (rx_sync) begin
                        data       <= shift_register;
                        data_valid <= 1'b1;
                    end
                end else begin
                    clock_count <= clock_count + 16'd1;
                end
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule
