`timescale 1ns / 1ps

module iir_highpass (
    input wire clk,
    input wire rst_n,
    input wire signed [15:0] d_in,
    input wire input_valid,
    output reg signed [15:0] d_out,
    output reg output_valid
);

    // --- 2nd Order Bandpass Coefficients (Q2.14 Fixed Point) ---
    // User Provided MATLAB Design:
    // num = [0.0591907, 0, -0.0591907]
    // den = [1, -1.7930638, 0.8816186]
    // Scale = 16384 (2^14)
    
    parameter signed [15:0] b0 = 16'sd970;    // +0.05919 * 16384
    parameter signed [15:0] b1 = 16'sd0;      //  0.0
    parameter signed [15:0] b2 = -16'sd970;   // -0.05919 * 16384
    
    // Feedback coefficients (Negated from MATLAB den for additive logic)
    // a1_rtl = -(-1.79306) * 16384 = +29378
    // a2_rtl = -(+0.88161) * 16384 = -14444
    parameter signed [15:0] a1 = 16'sd29378;  
    parameter signed [15:0] a2 = -16'sd14444; 

    // --- Internal State (Double Delay Line for 2nd Order) ---
    reg signed [15:0] x_prev1, x_prev2;
    reg signed [31:0] y_prev1, y_prev2; // High precision for feedback
    
    // --- 64-bit Intermediate Logic (Prevents Overflow) ---
    // We use 64-bit to safely hold the result of (32-bit * 16-bit)
    reg signed [63:0] p_b0, p_b1, p_b2;
    reg signed [63:0] p_a1, p_a2;
    reg signed [63:0] acc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_prev1 <= 0; x_prev2 <= 0;
            y_prev1 <= 0; y_prev2 <= 0;
            d_out <= 0;
            output_valid <= 0;
        end else if (input_valid) begin
            // 1. Compute Products (Cast to 64-bit first)
            // Feedforward (Inputs)
            p_b0 = $signed(d_in)    * $signed(b0);
            p_b1 = $signed(x_prev1) * $signed(b1);
            p_b2 = $signed(x_prev2) * $signed(b2);
            
            // Feedback (Outputs)
            // y_prev is Q18.14, a is Q2.14 -> Result Q20.28. 
            // Arithmetic Shift Right (>>>) by 14 to realign to Q18.14
            p_a1 = ($signed(y_prev1) * $signed(a1)) >>> 14;
            p_a2 = ($signed(y_prev2) * $signed(a2)) >>> 14;

            // 2. Accumulate (Direct Form I Difference Equation)
            // y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] + a1*y[n-1] + a2*y[n-2]
            acc = p_b0 + p_b1 + p_b2 + p_a1 + p_a2;

            // 3. Update State Registers (Shift history)
            x_prev2 <= x_prev1;
            x_prev1 <= d_in;
            
            y_prev2 <= y_prev1;
            
            // Clamp State to 32-bit to prevent internal wrap-around
            if (acc > 64'sd2147483647) y_prev1 <= 32'sd2147483647;
            else if (acc < -64'sd2147483648) y_prev1 <= -32'sd2147483648;
            else y_prev1 <= acc[31:0];

            // 4. Output Scaling & Saturation (Back to 16-bit Integer)
            // Result is Qxx.14. Shift right by 14 to get Integer.
            if ((acc >>> 14) > 64'sd32767) 
                d_out <= 16'sd32767;
            else if ((acc >>> 14) < -64'sd32768) 
                d_out <= -16'sd32768;
            else 
                d_out <= acc[29:14]; // Select integer bits

            output_valid <= 1;
        end else begin
            output_valid <= 0;
        end
    end

endmodule