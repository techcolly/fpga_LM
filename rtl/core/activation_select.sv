// activation_select.sv — passes the input_vector byte in the hidden layer pass and the hidden_buf byte in the output layer pass.

module activation_select (
    input   logic output_layer,
            logic signed[7:0] input_activation, hidden_activation,

    output  logic signed[7:0] activation
);

always_comb begin
    case (output_layer)
        1'b0:    activation = input_activation;
        1'b1:    activation = hidden_activation;
        default: activation = 8'sd0;
    endcase
end

endmodule
