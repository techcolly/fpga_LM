// fpga_top.sv — Arty A7 top level: UART in -> request_collector -> inference datapath -> UART out; LEDs show the last predicted token. DEBUG=1 adds a VIO request path and an ILA.

module fpga_top #(
    parameter int    CLOCKS_PER_BIT = 868,
    parameter string WEIGHT_FILE    = "weight_rom.mem",
    parameter string BIAS_FILE      = "bias_rom.mem",
    parameter string EMBED_FILE     = "embed_rom.mem",
    parameter bit    DEBUG          = 1'b0
) (
    input   logic CLK100MHZ, reset_button, uart_txd_in,

    output  logic uart_rxd_out,
            logic[3:0] led
);

logic reset_meta, reset;

logic[7:0]  rx_data, collector_data;
logic       rx_valid, collector_valid;
logic[5:0]  embed_address;
logic       tx_busy;

logic       input_vector_we, load_bias, accumulate_en, hidden_we, compare_en, argmax_clear, done, output_layer, start;
logic[1:0]  token_index;
logic[2:0]  group_index, lane_index;
logic[3:0]  bias_address, state;
logic[4:0]  input_index;
logic[8:0]  weight_address;

logic[63:0]  embed_data, weight_word, hidden_word;
logic[255:0] bias_word, accumulator_word;

logic signed[7:0]  input_activation, hidden_activation, activation;
logic signed[31:0] best_value;
logic[5:0]         best_index, last_token;
logic[7:0]         inference_count;

always_ff @(posedge CLK100MHZ) begin
    reset_meta <= reset_button;
    reset      <= reset_meta;
end

always_ff @(posedge CLK100MHZ) begin
    if (reset) begin
        last_token      <= 6'd0;
        inference_count <= 8'd0;
    end else if (done) begin
        last_token      <= best_index;
        inference_count <= inference_count + 8'd1;
    end
end

assign led = last_token[3:0];

uart_rx #(.CLOCKS_PER_BIT(CLOCKS_PER_BIT)) uart_rx_unit (
    .clk        (CLK100MHZ),
    .reset      (reset),
    .rx         (uart_txd_in),
    .data       (rx_data),
    .data_valid (rx_valid)
);

request_collector collector_unit (
    .clk           (CLK100MHZ),
    .reset         (reset),
    .rx_valid      (collector_valid),
    .busy          (!argmax_clear),
    .rx_data       (collector_data),
    .token_index   (token_index),
    .start         (start),
    .embed_address (embed_address)
);

inference_fsm fsm_unit (
    .clk             (CLK100MHZ),
    .reset           (reset),
    .start           (start),
    .input_vector_we (input_vector_we),
    .load_bias       (load_bias),
    .accumulate_en   (accumulate_en),
    .hidden_we       (hidden_we),
    .compare_en      (compare_en),
    .argmax_clear    (argmax_clear),
    .done            (done),
    .output_layer    (output_layer),
    .token_index     (token_index),
    .group_index     (group_index),
    .lane_index      (lane_index),
    .bias_address    (bias_address),
    .state           (state),
    .input_index     (input_index),
    .weight_address  (weight_address)
);

embed_rom #(.INIT_FILE(EMBED_FILE)) embed_rom_unit (
    .clk     (CLK100MHZ),
    .address (embed_address),
    .data    (embed_data)
);

weight_rom #(.INIT_FILE(WEIGHT_FILE)) weight_rom_unit (
    .clk     (CLK100MHZ),
    .address (weight_address),
    .data    (weight_word)
);

bias_rom #(.INIT_FILE(BIAS_FILE)) bias_rom_unit (
    .clk     (CLK100MHZ),
    .address (bias_address),
    .data    (bias_word)
);

input_vector input_vector_unit (
    .clk              (CLK100MHZ),
    .input_vector_we  (input_vector_we),
    .token_index      (token_index),
    .input_index      (input_index),
    .embed_data       (embed_data),
    .input_activation (input_activation)
);

hidden_buf hidden_buf_unit (
    .clk               (CLK100MHZ),
    .hidden_we         (hidden_we),
    .group_index       (group_index[1:0]),
    .input_index       (input_index),
    .hidden_word       (hidden_word),
    .hidden_activation (hidden_activation)
);

activation_select activation_select_unit (
    .output_layer      (output_layer),
    .input_activation  (input_activation),
    .hidden_activation (hidden_activation),
    .activation        (activation)
);

mac_array mac_array_unit (
    .clk              (CLK100MHZ),
    .load_bias        (load_bias),
    .accumulate_en    (accumulate_en),
    .activation       (activation),
    .weight_word      (weight_word),
    .bias_word        (bias_word),
    .accumulator_word (accumulator_word)
);

post_process post_process_unit (
    .accumulator_word (accumulator_word),
    .hidden_word      (hidden_word)
);

argmax argmax_unit (
    .clk              (CLK100MHZ),
    .compare_en       (compare_en),
    .argmax_clear     (argmax_clear),
    .accumulator_word (accumulator_word),
    .group_index      (group_index),
    .lane_index       (lane_index),
    .best_value       (best_value),
    .best_index       (best_index)
);

uart_tx #(.CLOCKS_PER_BIT(CLOCKS_PER_BIT)) uart_tx_unit (
    .clk   (CLK100MHZ),
    .reset (reset),
    .send  (done),
    .data  ({2'b00, best_index}),
    .tx    (uart_rxd_out),
    .busy  (tx_busy)
);

generate
    if (DEBUG) begin : debug_block
        logic[23:0] vio_tokens;
        logic       vio_go, go_previous, inject_active;
        logic[1:0]  inject_count;

        always_ff @(posedge CLK100MHZ) begin
            go_previous <= vio_go;
            if (reset) begin
                inject_active <= 1'b0;
                inject_count  <= 2'd0;
            end else if (!inject_active) begin
                if (vio_go && !go_previous) begin
                    inject_active <= 1'b1;
                    inject_count  <= 2'd0;
                end
            end else begin
                inject_count <= inject_count + 2'd1;
                if (inject_count == 2'd3) inject_active <= 1'b0;
            end
        end

        assign collector_valid = rx_valid || inject_active;
        assign collector_data  = inject_active ? {2'b00, vio_tokens[6*inject_count +: 6]} : rx_data;

        vio_0 vio_unit (
            .clk        (CLK100MHZ),
            .probe_in0  (last_token),
            .probe_in1  (inference_count),
            .probe_in2  (state),
            .probe_out0 (vio_tokens),
            .probe_out1 (vio_go)
        );

        ila_0 ila_unit (
            .clk    (CLK100MHZ),
            .probe0 (state),
            .probe1 (start),
            .probe2 ({done, rx_valid, tx_busy, input_vector_we, load_bias, accumulate_en, hidden_we, compare_en, argmax_clear, output_layer}),
            .probe3 (input_index),
            .probe4 (group_index),
            .probe5 (lane_index),
            .probe6 (weight_address),
            .probe7 (activation),
            .probe8 (accumulator_word[31:0]),
            .probe9 (best_value),
            .probe10 (best_index),
            .probe11 ({uart_rxd_out, uart_txd_in})
        );
    end else begin : normal_path
        assign collector_valid = rx_valid;
        assign collector_data  = rx_data;
    end
endgenerate

endmodule
