`timescale 1ns / 1ps

module cic_decimator (
    input wire clk,
    input wire rst_n,
    input wire d_in,
    input wire input_valid,
    output reg signed [15:0] d_out,
    output reg output_valid
);

    parameter DECIMATION_RATIO = 64;
    parameter REGISTER_WIDTH = 25; 

    // Extend Input
    wire signed [REGISTER_WIDTH-1:0] extended_input;
    assign extended_input = d_in ? 25'sd1 : -25'sd1;

    // Registers
    reg signed [REGISTER_WIDTH-1:0] int_1, int_2, int_3, int_4;
    reg signed [REGISTER_WIDTH-1:0] comb_1_d, comb_2_d, comb_3_d, comb_4_d;
    wire signed [REGISTER_WIDTH-1:0] comb_1_out, comb_2_out, comb_3_out, comb_4_out;

    reg [5:0] count;
    reg decim_strobe;

    // Integrator Stage
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            int_1 <= 0; int_2 <= 0; int_3 <= 0; int_4 <= 0;
            count <= 0; decim_strobe <= 0;
        end else if (input_valid) begin
            int_1 <= int_1 + extended_input;
            int_2 <= int_2 + int_1;
            int_3 <= int_3 + int_2;
            int_4 <= int_4 + int_3;

            if (count == DECIMATION_RATIO - 1) begin
                count <= 0;
                decim_strobe <= 1;
            end else begin
                count <= count + 1;
                decim_strobe <= 0;
            end
        end else begin
            decim_strobe <= 0;
        end
    end

    // Comb Stage
    assign comb_1_out = int_4 - comb_1_d;
    assign comb_2_out = comb_1_out - comb_2_d;
    assign comb_3_out = comb_2_out - comb_3_d;
    assign comb_4_out = comb_3_out - comb_4_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            comb_1_d <= 0; comb_2_d <= 0; comb_3_d <= 0; comb_4_d <= 0;
            d_out <= 0; output_valid <= 0;
        end else if (decim_strobe) begin
            comb_1_d <= int_4;
            comb_2_d <= comb_1_out;
            comb_3_d <= comb_2_out;
            comb_4_d <= comb_3_out;

            // Optimized Gain Selection (High Amplitude)
            d_out <= comb_4_out[24:9]; 
            output_valid <= 1;
        end else begin
            output_valid <= 0;
        end
    end
endmodule