// tb_activation_path.sv — checks input_vector, hidden_buf and activation_select together: byte order, write enables, overwrites.

module tb_activation_path;

logic               clk, input_vector_we, hidden_we, output_layer;
logic[1:0]          token_index, group_index;
logic[4:0]          input_index;
logic[63:0]         embed_data, hidden_word;
logic signed[7:0]   input_activation, hidden_activation, activation;

int                 errors;
int                 input_values[32], hidden_values[32];

input_vector      input_vector_unit      (.*);
hidden_buf        hidden_buf_unit        (.*);
activation_select activation_select_unit (.*);

initial clk = 1'b0;
always #5 clk = ~clk;

function logic[63:0] pack_word(input int values[32], input int word);
    for (int byte_index = 0; byte_index < 8; byte_index++)
        pack_word[8*byte_index +: 8] = values[8*word + byte_index];
endfunction

task write_input_word(input int word);
    token_index     = word;
    embed_data      = pack_word(input_values, word);
    input_vector_we = 1'b1;
    @(negedge clk);
    input_vector_we = 1'b0;
endtask

task write_hidden_word(input int word);
    group_index = word;
    hidden_word = pack_word(hidden_values, word);
    hidden_we   = 1'b1;
    @(negedge clk);
    hidden_we   = 1'b0;
endtask

task check_all_reads(input string message);
    int actual_value;

    for (int index = 0; index < 32; index++) begin
        input_index  = index;
        output_layer = 1'b0;
        #1;
        actual_value = activation;
        if (actual_value !== input_values[index]) begin
            $display("FAIL %s: output_layer=0 byte %0d is %0d, expected %0d", message, index, actual_value, input_values[index]);
            errors++;
        end
        output_layer = 1'b1;
        #1;
        actual_value = activation;
        if (actual_value !== hidden_values[index]) begin
            $display("FAIL %s: output_layer=1 byte %0d is %0d, expected %0d", message, index, actual_value, hidden_values[index]);
            errors++;
        end
    end
endtask

initial begin
    errors          = 0;
    input_vector_we = 1'b0;
    hidden_we       = 1'b0;
    token_index     = 2'd0;
    group_index     = 2'd0;
    embed_data      = 64'd0;
    hidden_word     = 64'd0;
    @(negedge clk);

    // distinct signed values; input byte j = token word j/8, element j%8, as in the concatenated input vector
    for (int index = 0; index < 32; index++) begin
        input_values[index]  = 10*(index / 8) + (index % 8) - 20;
        hidden_values[index] = index * 3;
    end

    // write the words out of order to show each word lands in its own slot
    write_input_word(2);
    write_input_word(0);
    write_input_word(3);
    write_input_word(1);
    write_hidden_word(3);
    write_hidden_word(1);
    write_hidden_word(0);
    write_hidden_word(2);
    check_all_reads("after first writes");

    // overwrite one word of each buffer; the other words must not change
    for (int byte_index = 0; byte_index < 8; byte_index++) begin
        input_values[16 + byte_index]  = -128 + byte_index;
        hidden_values[8 + byte_index]  = 127 - byte_index;
    end
    write_input_word(2);
    write_hidden_word(1);
    check_all_reads("after overwrite");

    // nothing changes while a write enable is low, even if data and index change
    token_index = 2'd1;
    embed_data  = 64'hFFFFFFFFFFFFFFFF;
    group_index = 2'd2;
    hidden_word = 64'hFFFFFFFFFFFFFFFF;
    @(negedge clk);
    @(negedge clk);
    check_all_reads("write enables low");

    if (errors == 0) $display("PASS: activation_path");
    else             $display("FAIL: %0d errors", errors);
    $finish;
end

endmodule
