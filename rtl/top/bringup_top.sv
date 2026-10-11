// bringup_top.sv — board bring-up only: the 100 MHz clock, divided clocks and a 0x55 UART stream on Pmod JB for a scope, LED blinks, and a serial echo.

module bringup_top #(
    parameter int CLOCKS_PER_BIT = 868
) (
    input   logic CLK100MHZ, reset_button, uart_txd_in,

    output  logic uart_rxd_out, clock_forward,
            logic[3:0] led,
            logic[3:0] jb
);

logic[31:0] divider = 32'd0;
logic[22:0] activity_count = 23'd0;
logic       reset_meta, reset;
logic[7:0]  rx_data;
logic       rx_valid, echo_busy, scope_busy, scope_tx;

always_ff @(posedge CLK100MHZ) divider <= divider + 32'd1;

always_ff @(posedge CLK100MHZ) begin
    reset_meta <= reset_button;
    reset      <= reset_meta;
end

always_ff @(posedge CLK100MHZ) begin
    if (rx_valid)                  activity_count <= 23'h7FFFFF;
    else if (activity_count != 0)  activity_count <= activity_count - 23'd1;
end

assign led = {reset_button, (activity_count != 0), divider[24], divider[25]};
assign jb  = {scope_tx, divider[16], divider[6], divider[0]};

ODDR #(
    .DDR_CLK_EDGE ("OPPOSITE_EDGE"),
    .INIT         (1'b0),
    .SRTYPE       ("SYNC")
) clock_forward_unit (
    .Q  (clock_forward),
    .C  (CLK100MHZ),
    .CE (1'b1),
    .D1 (1'b1),
    .D2 (1'b0),
    .R  (1'b0),
    .S  (1'b0)
);

uart_rx #(.CLOCKS_PER_BIT(CLOCKS_PER_BIT)) rx_unit (
    .clk        (CLK100MHZ),
    .reset      (reset),
    .rx         (uart_txd_in),
    .data       (rx_data),
    .data_valid (rx_valid)
);

uart_tx #(.CLOCKS_PER_BIT(CLOCKS_PER_BIT)) echo_unit (
    .clk   (CLK100MHZ),
    .reset (reset),
    .send  (rx_valid),
    .data  (rx_data),
    .tx    (uart_rxd_out),
    .busy  (echo_busy)
);

uart_tx #(.CLOCKS_PER_BIT(CLOCKS_PER_BIT)) scope_unit (
    .clk   (CLK100MHZ),
    .reset (reset),
    .send  (1'b1),
    .data  (8'h55),
    .tx    (scope_tx),
    .busy  (scope_busy)
);

endmodule
