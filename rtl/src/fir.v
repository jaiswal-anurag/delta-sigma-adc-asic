`timescale 1ns / 1ps

module fir_decimator (
    input wire clk,
    input wire rst_n,
    input wire signed [15:0] d_in,
    input wire input_valid,
    output reg signed [15:0] d_out,
    output reg output_valid
);

    parameter TAPS = 51;
    
    reg signed [15:0] coeffs [0:TAPS-1];
    reg signed [15:0] shift_reg [0:TAPS-1];
    reg decim_phase; 
    reg signed [39:0] acc; 
    integer i;

    initial begin
        $readmemh("coeffs_hex.txt", coeffs);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            decim_phase <= 0;
            d_out <= 0;
            output_valid <= 0;
            acc <= 0;
            for (i=0; i<TAPS; i=i+1) shift_reg[i] <= 0;
        end else if (input_valid) begin
            shift_reg[0] <= d_in;
            for (i=1; i<TAPS; i=i+1) shift_reg[i] <= shift_reg[i-1];

            if (decim_phase == 1) begin
                acc = 0;
                for (i=0; i<TAPS; i=i+1) begin
                    acc = acc + (shift_reg[i] * coeffs[i]);
                end
                
                // --- FIX FOR OVERFLOW/WRAPPING ---
                // Coeffs are Q1.15. To convert back to integer, we theoretically shift right by 15.
                // acc is 40-bit. 
                // We perform the shift first to align the binary point.
                // Then we check if the RESULT fits in 16 bits.
                
                // 1. Arithmetic Shift Right by 15 to remove fractional part
                // Using a temporary variable for clarity (simulation only logic)
                // In hardware: acc[39:15] is the integer part (roughly)
                
                // Saturate logic based on the shifted value
                if ((acc >>> 15) > 32'sd32767) 
                    d_out <= 16'sd32767;
                else if ((acc >>> 15) < -32'sd32768)
                    d_out <= -16'sd32768;
                else
                    d_out <= acc[30:15]; // Take bits 15 to 30 (16 bits)

                output_valid <= 1;
                decim_phase <= 0;
            end else begin
                output_valid <= 0;
                decim_phase <= 1;
            end
        end else begin
            output_valid <= 0;
        end
    end
endmodule