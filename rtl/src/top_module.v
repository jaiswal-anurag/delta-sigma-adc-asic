`timescale 1ns / 1ps

module filter_chain_top (
    input wire clk,
    input wire rst_n,
    input wire d_in,
    input wire input_valid,
    output wire signed [15:0] d_out,
    output wire output_valid
);

    wire signed [15:0] cic_data;
    wire cic_valid;
    wire signed [15:0] fir_data;
    wire fir_valid;

    cic_decimator cic (
        .clk(clk), .rst_n(rst_n), .d_in(d_in), .input_valid(input_valid),
        .d_out(cic_data), .output_valid(cic_valid)
    );

    fir_decimator fir (
        .clk(clk), .rst_n(rst_n), .d_in(cic_data), .input_valid(cic_valid),
        .d_out(fir_data), .output_valid(fir_valid)
    );

    iir_highpass iir (
        .clk(clk), .rst_n(rst_n), .d_in(fir_data), .input_valid(fir_valid),
        .d_out(d_out), .output_valid(output_valid)
    );

endmodule