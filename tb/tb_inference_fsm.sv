// tb_inference_fsm.sv — compares the FSM against an independently built expected trace on every clock cycle.

module tb_inference_fsm;

typedef enum logic[3:0] {
    IDLE         = 4'd0,
    EMBED_READ   = 4'd1,
    EMBED_STORE  = 4'd2,
    BIAS_READ    = 4'd3,
    BIAS_LOAD    = 4'd4,
    WEIGHT_READ  = 4'd5,
    ACCUMULATE   = 4'd6,
    HIDDEN_STORE = 4'd7,
    ARGMAX       = 4'd8,
    DONE         = 4'd9,
    DRAIN        = 4'd10
} state_names_t;

typedef struct packed {
    logic[3:0] state;
    logic[1:0] token_index;
    logic[2:0] group_index, lane_index;
    logic[4:0] input_index;
    logic[8:0] weight_address;
    logic[3:0] bias_address;
    logic      output_layer;
} snapshot_t;

localparam int TOTAL_CYCLES = 881;

logic           clk, reset, start;
logic           input_vector_we, load_bias, accumulate_en, hidden_we, compare_en, argmax_clear, done;
logic           output_layer;
logic[1:0]      token_index;
logic[2:0]      group_index, lane_index;
logic[3:0]      bias_address, state;
logic[4:0]      input_index;
logic[8:0]      weight_address;

state_names_t   state_name;
snapshot_t      expected[TOTAL_CYCLES];
int             errors;
int             count, e_token, e_group, e_input, e_lane, e_weight, e_bias, e_layer;

inference_fsm dut (.*);

initial clk = 1'b0;
always #5 clk = ~clk;

assign state_name = state_names_t'(state);

function logic[6:0] expected_outputs(input logic[3:0] s);
    case (s)
        EMBED_STORE:  expected_outputs = 7'b1000000;
        BIAS_LOAD:    expected_outputs = 7'b0100000;
        ACCUMULATE:   expected_outputs = 7'b0010000;
        HIDDEN_STORE: expected_outputs = 7'b0001000;
        ARGMAX:       expected_outputs = 7'b0000100;
        IDLE:         expected_outputs = 7'b0000010;
        DONE:         expected_outputs = 7'b0000001;
        default:      expected_outputs = 7'b0000000;
    endcase
endfunction

task add(input logic[3:0] s);
    expected[count] = '{s, e_token[1:0], e_group[2:0], e_lane[2:0], e_input[4:0], e_weight[8:0], e_bias[3:0], e_layer[0]};
    count++;
endtask

task build_expected;
    count = 0;  e_token = 0;  e_group = 0;  e_input = 0;
    e_lane = 0; e_weight = 0; e_bias = 0;   e_layer = 0;

    for (e_token = 0; e_token < 4; e_token++) begin
        add(EMBED_READ);
        add(EMBED_STORE);
    end
    e_token = 3;

    for (e_layer = 0; e_layer < 2; e_layer++) begin
        for (e_group = 0; e_group < (e_layer == 0 ? 4 : 8); e_group++) begin
            add(BIAS_READ);
            add(BIAS_LOAD);
            e_bias++;
            for (e_input = 0; e_input < 32; e_input++) begin
                add(WEIGHT_READ);
                add(ACCUMULATE);
                e_weight++;
            end
            e_input = 0;
            add(DRAIN);
            if (e_layer == 0) add(HIDDEN_STORE);
            else begin
                for (e_lane = 0; e_lane < 8; e_lane++) add(ARGMAX);
                e_lane = 0;
            end
        end
    end

    e_group = 7;
    e_layer = 1;
    add(DONE);
endtask

task mismatch(input int index, input string field, input int actual_value, input int expected_value);
    if (errors < 20) $display("FAIL cycle %0d: %s is %0d, expected %0d", index, field, actual_value, expected_value);
    errors++;
endtask

task check_cycle(input int index);
    snapshot_t actual;
    logic[6:0] actual_outputs;

    actual         = '{state, token_index, group_index, lane_index, input_index, weight_address, bias_address, output_layer};
    actual_outputs = {input_vector_we, load_bias, accumulate_en, hidden_we, compare_en, argmax_clear, done};

    if (actual.state          !== expected[index].state)          mismatch(index, "state",          actual.state,          expected[index].state);
    if (actual.token_index    !== expected[index].token_index)    mismatch(index, "token_index",    actual.token_index,    expected[index].token_index);
    if (actual.group_index    !== expected[index].group_index)    mismatch(index, "group_index",    actual.group_index,    expected[index].group_index);
    if (actual.lane_index     !== expected[index].lane_index)     mismatch(index, "lane_index",     actual.lane_index,     expected[index].lane_index);
    if (actual.input_index    !== expected[index].input_index)    mismatch(index, "input_index",    actual.input_index,    expected[index].input_index);
    if (actual.weight_address !== expected[index].weight_address) mismatch(index, "weight_address", actual.weight_address, expected[index].weight_address);
    if (actual.bias_address   !== expected[index].bias_address)   mismatch(index, "bias_address",   actual.bias_address,   expected[index].bias_address);
    if (actual.output_layer   !== expected[index].output_layer)   mismatch(index, "output_layer",   actual.output_layer,   expected[index].output_layer);
    if (actual_outputs !== expected_outputs(expected[index].state)) mismatch(index, "control outputs {we,bias,acc,hidden,cmp,clr,done}", actual_outputs, expected_outputs(expected[index].state));
endtask

task run_inference(input int run_number);
    @(negedge clk) start = 1'b1;
    @(negedge clk) start = 1'b0;

    for (int index = 0; index < TOTAL_CYCLES; index++) begin
        check_cycle(index);
        @(negedge clk);
    end

    if (state !== IDLE)  mismatch(TOTAL_CYCLES, "state after DONE", state, IDLE);
    if (argmax_clear !== 1'b1) mismatch(TOTAL_CYCLES, "argmax_clear after DONE", argmax_clear, 1);

    @(negedge clk);
    if ({token_index, group_index, lane_index, input_index, weight_address, bias_address, output_layer} !== '0)
        mismatch(TOTAL_CYCLES + 1, "counters not all cleared in IDLE", 1, 0);

    $display("run %0d: checked %0d cycles", run_number, TOTAL_CYCLES);
endtask

initial begin
    #1000000;
    $display("FAIL: timeout");
    $finish;
end

initial begin
    errors = 0;
    build_expected();
    if (count !== TOTAL_CYCLES) begin
        $display("FAIL: testbench built %0d expected cycles, wanted %0d", count, TOTAL_CYCLES);
        $finish;
    end

    reset = 1'b1;
    start = 1'b0;
    repeat (3) @(negedge clk);
    reset = 1'b0;
    repeat (2) @(negedge clk);

    run_inference(1);
    run_inference(2);

    if (errors == 0) $display("PASS: inference_fsm");
    else             $display("FAIL: %0d errors", errors);
    $finish;
end

endmodule
