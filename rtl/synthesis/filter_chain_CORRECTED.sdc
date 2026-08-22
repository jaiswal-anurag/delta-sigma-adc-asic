# ═══════════════════════════════════════════════════════════════════════════════
# TIMING CONSTRAINTS FOR DIGITAL FILTER CHAIN (CORRECTED VERSION)
# Design: CIC + FIR + IIR Decimation Filter
# Target: 50 MHz (20 ns period) - Matches testbench
# Fixed: All SDC errors from previous run
# ═══════════════════════════════════════════════════════════════════════════════

#==============================================================================
# CLOCK DEFINITION
#==============================================================================

# Main clock - 50 MHz (matches your testbench)
create_clock -name clk -period 20.0 [get_ports clk]

# Clock uncertainty (jitter + skew)
set_clock_uncertainty 1.0 [get_clocks clk]

# Clock transition (rise/fall time)
set_clock_transition 0.15 [get_clocks clk]

# Protect clock network from optimization
set_dont_touch_network [get_clocks clk]

#==============================================================================
# INPUT TIMING CONSTRAINTS
#==============================================================================

# Input delay: Time after clock edge when input data arrives
set input_delay_value 2.0

# Apply to all inputs except clock and reset
set_input_delay -clock clk $input_delay_value [get_ports d_in]
set_input_delay -clock clk $input_delay_value [get_ports input_valid]

# Reset timing (asynchronous but give it some constraint)
set_input_delay -clock clk 1.0 [get_ports rst_n]

# Input driving strength (external driver capability)
set_driving_cell -lib_cell INVX1 -pin Y [get_ports {d_in input_valid}]

# Input transition time (signal quality from external source)
set_input_transition 0.3 [get_ports {d_in input_valid rst_n}]

#==============================================================================
# OUTPUT TIMING CONSTRAINTS
#==============================================================================

# Output delay: Time before next clock edge when output must be stable
set output_delay_value 3.0

set_output_delay -clock clk $output_delay_value [get_ports d_out]
set_output_delay -clock clk $output_delay_value [get_ports output_valid]

# Output load (capacitance of external circuitry)
set_load 0.5 [get_ports {d_out output_valid}]

#==============================================================================
# DESIGN RULE CONSTRAINTS
#==============================================================================

# Maximum fanout (number of gates one output can drive)
set_max_fanout 20 [current_design]

# Maximum transition time (slew rate limit)
set_max_transition 0.8 [current_design]

# Maximum capacitance per net
set_max_capacitance 1.5 [current_design]

#==============================================================================
# FALSE PATHS (Paths not needing timing analysis)
#==============================================================================

# Asynchronous reset paths
set_false_path -from [get_ports rst_n] -to [all_registers]

#==============================================================================
# NOTES ON REMOVED/COMMENTED ITEMS
#==============================================================================
#
# REMOVED: group_path commands
# Reason: The get_pins commands were failing because the hierarchical 
#         paths don't exist after elaboration. The synthesis tool will
#         automatically identify and optimize critical paths.
#
# Original commands that failed:
# - group_path -name FIR_CRITICAL -from [get_pins fir/shift_reg*] ...
# - group_path -name CIC_INTEGRATORS -from [get_pins cic/int_*] ...  
# - group_path -name IIR_FEEDBACK -from [get_pins iir/y_prev*] ...
#
# These are NOT needed - Genus will find critical paths automatically.
#
#==============================================================================

#==============================================================================
# SUMMARY OF CONSTRAINTS
#==============================================================================
#
# Clock Period:        20.0 ns (50 MHz)
# Input Delay:         2.0 ns
# Output Delay:        3.0 ns
# Available for Logic: 20 - 2 - 3 = 15 ns
#
# Expected Critical Paths:
# 1. FIR MAC loop:        ~13.3 ns (51 taps multiply-accumulate)
# 2. CIC integrator chain: ~3.5 ns (4 cascaded 25-bit adders)
# 3. IIR feedback path:    ~3.0 ns (64-bit arithmetic + saturation)
#
# With 15 ns available and ~13.3 ns expected FIR delay:
# Expected slack: ~1.7 ns (TIGHT but should work)
#
#==============================================================================

# End of constraints file
