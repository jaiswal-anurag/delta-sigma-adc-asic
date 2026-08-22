`timescale 1ns / 1ps

module tb_filter_chain;

    // Signals
    reg clk;
    reg rst_n;
    reg d_in;
    reg input_valid;
    wire signed [15:0] d_out;
    wire output_valid;

    // Simulation Variables
    integer file_in, file_out, scan_status;
    integer temp_val;
    integer sample_count;
    integer out_count;

    // Instantiate Top Module
    filter_chain_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .d_in(d_in),
        .input_valid(input_valid),
        .d_out(d_out),
        .output_valid(output_valid)
    );

    // Clock Generation (50 MHz)
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 20ns period
    end

    // File Operations & Stimulus
    initial begin
        // 1. Setup
        $display("---------------------------------------");
        $display("Starting Filter Chain Simulation...");
        $display("---------------------------------------");
        
        file_in = $fopen("input_samples.txt", "r");
        file_out = $fopen("output_results.txt", "w");
        
        if (file_in == 0) begin
            $display("ERROR: Could not open input_samples.txt!");
            $finish;
        end

        // 2. Initialize Signals
        rst_n = 0;
        d_in = 0;
        input_valid = 0;
        sample_count = 0;
        out_count = 0;

        // 3. Apply Reset
        #100;
        rst_n = 1;
        #100;
        $display("Reset released. Processing data...");

        // 4. Processing Loop
        // Read until End of File (EOF)
        while (!$feof(file_in)) begin
            scan_status = $fscanf(file_in, "%d\n", temp_val);
            
            if (scan_status == 1) begin
                // Drive Input
                d_in = temp_val[0]; // Take LSB (0 or 1)
                input_valid = 1;
                
                // Hold valid for 1 clock cycle (20ns)
                #20; 
                input_valid = 0;

                // Wait for the sample rate period (256 kHz)
                // Period = 1/256000 = 3906.25 ns
                // We already spent 20ns, so wait 3886ns
                #3886; 
                
                sample_count = sample_count + 1;
                
                // Progress indicator every 1000 samples
                if (sample_count % 1000 == 0) 
                    $display("Processed %d input samples...", sample_count);
            end
        end

        // 5. Cleanup
        #10000; // Wait for pipeline to flush
        $fclose(file_in);
        $fclose(file_out);
        
        $display("---------------------------------------");
        $display("Simulation Complete!");
        $display("Total Input Samples: %d", sample_count);
        $display("Total Output Samples: %d", out_count);
        $display("Results saved to: output_results.txt");
        $display("---------------------------------------");
        $finish;
    end

    // Monitor Output
    always @(posedge clk) begin
        if (output_valid) begin
            $fwrite(file_out, "%d\n", d_out);
            // Optional: Print first few outputs to terminal to verify
            if (out_count < 10) 
                $display("Time: %t | Output: %d", $time, d_out);
            out_count = out_count + 1;
        end
    end

endmodule