// tb_argmax.sv — feeds 64 logits in FSM order (8 groups of 8 lanes) and checks the winner against a two-pass reference.

module tb_argmax;

logic               clk, compare_en, argmax_clear;
logic[255:0]        accumulator_word;
logic[2:0]          group_index, lane_index;
logic signed[31:0]  best_value;
logic[5:0]          best_index;

int                 logits[64];
int                 errors;

argmax dut (.*);

initial clk = 1'b0;
always #5 clk = ~clk;

// reference: find the maximum first, then the lowest index holding it
function int expected_value;
    int maximum;

    maximum = logits[0];
    for (int index = 1; index < 64; index++) if (logits[index] > maximum) maximum = logits[index];
    return maximum;
endfunction

function int expected_index;
    int maximum;

    maximum = expected_value();
    for (int index = 0; index < 64; index++) if (logits[index] == maximum) return index;
    return 0;
endfunction

task clear_argmax;
    compare_en   = 1'b0;
    argmax_clear = 1'b1;
    @(negedge clk);
    argmax_clear = 1'b0;
    if (best_value !== 32'sh80000000 || best_index !== 6'd0) begin
        $display("FAIL clear: best_value is %0d, best_index is %0d", best_value, best_index);
        errors++;
    end
endtask

task run_trial(input string message);
    clear_argmax();

    for (int group_number = 0; group_number < 8; group_number++) begin
        for (int lane = 0; lane < 8; lane++) accumulator_word[32*lane +: 32] = logits[8*group_number + lane];
        for (int lane = 0; lane < 8; lane++) begin
            group_index = group_number;
            lane_index  = lane;
            compare_en  = 1'b1;
            @(negedge clk);
        end
    end
    compare_en = 1'b0;

    if (best_value !== expected_value() || best_index !== expected_index()) begin
        $display("FAIL %s: got value %0d index %0d, expected value %0d index %0d",
                 message, best_value, best_index, expected_value(), expected_index());
        errors++;
    end
endtask

initial begin
    #5000000;
    $display("FAIL: timeout at %0t", $time);
    $finish;
end

initial begin
    $display("tb_argmax started");
    errors       = 0;
    compare_en   = 1'b0;
    argmax_clear = 1'b0;
    group_index  = 3'd0;
    lane_index   = 3'd0;
    accumulator_word = 256'd0;
    @(negedge clk);

    // all logits equal: the first one (index 0) must win
    for (int index = 0; index < 64; index++) logits[index] = 5;
    run_trial("all equal");

    // two equal maxima: the lower index (10) must win
    for (int index = 0; index < 64; index++) logits[index] = index;
    logits[10] = 1000;
    logits[40] = 1000;
    run_trial("tie between index 10 and 40");

    // tie across groups, and the maximum in lane 0 of group 0, and in the very last lane
    for (int index = 0; index < 64; index++) logits[index] = -index;
    run_trial("maximum at index 0");
    for (int index = 0; index < 64; index++) logits[index] = index;
    run_trial("maximum at index 63");

    // all negative logits, including the most negative value (the same as the cleared start value)
    for (int index = 0; index < 64; index++) logits[index] = -100 - index;
    logits[37] = -3;
    run_trial("all negative");
    for (int index = 0; index < 64; index++) logits[index] = 32'sh80000000;
    run_trial("all most-negative");
    logits[22] = 32'sh80000001;
    run_trial("one value above the most-negative");

    $display("directed tests done at %0t, %0d errors so far", $time, errors);

    // random full-range logits
    repeat (300) begin
        for (int index = 0; index < 64; index++) logits[index] = $urandom;
        run_trial("random full range");
    end

    $display("random full-range tests done at %0t, %0d errors so far", $time, errors);

    // random small logits, which create many ties
    repeat (300) begin
        for (int index = 0; index < 64; index++) logits[index] = $urandom_range(0, 6) - 3;
        run_trial("random with ties");
    end

    // nothing changes while compare_en is low, even with larger logits present
    for (int index = 0; index < 64; index++) logits[index] = index;
    run_trial("before hold check");
    for (int lane = 0; lane < 8; lane++) accumulator_word[32*lane +: 32] = 32'sd2000000000;
    compare_en = 1'b0;
    @(negedge clk);
    @(negedge clk);
    if (best_value !== expected_value() || best_index !== expected_index()) begin
        $display("FAIL hold: best_value %0d best_index %0d changed while compare_en was low", best_value, best_index);
        errors++;
    end

    if (errors == 0) $display("PASS: argmax");
    else             $display("FAIL: %0d errors", errors);
    $finish;
end

endmodule
