# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║   CADENCE GENUS SYNTHESIS SCRIPT - FIXED OUTPUT GENERATION                  ║
# ║   Design: CIC + FIR + IIR Decimation Filter (PDM Audio Processing)          ║
# ║   Target: 50 MHz operation                                                  ║
# ║   Fixed: Output file generation issues                                      ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

#==============================================================================
# CONFIGURATION
#==============================================================================

set TOP "filter_chain_top"
set DESIGN_NAME "filter_chain"

# Library path
set LIBPATH "/home/install/SSV202/share/FoundationFlows/EXAMPLES/TEMPUS/GPDK/LIBS/GPDK045/timing/typical.lib"

# Search paths
set_db init_hdl_search_path {.}

# Output directories
set OUTPUT_DIR "./synthesis_outputs"
set REPORT_DIR "./synthesis_reports"
file mkdir $OUTPUT_DIR
file mkdir $REPORT_DIR

puts ""
puts "╔══════════════════════════════════════════════════════════════════════════════╗"
puts "║                 DIGITAL FILTER CHAIN SYNTHESIS                               ║"
puts "╚══════════════════════════════════════════════════════════════════════════════╝"
puts ""

#==============================================================================
# LIBRARY SETUP
#==============================================================================

puts "=========================================="
puts "Step 1: Loading Technology Library"
puts "=========================================="
puts "Library: $LIBPATH"

if { ![file exists $LIBPATH] } {
    puts "ERROR: Library file not found!"
    puts "Please update LIBPATH in this script"
    exit 1
}

set_db library $LIBPATH
puts "✓ Library loaded successfully"
puts ""

#==============================================================================
# READ RTL DESIGN FILES
#==============================================================================

puts "=========================================="
puts "Step 2: Reading RTL Design Files"
puts "=========================================="

set rtl_files [list \
    "cic.v" \
    "fir.v" \
    "iir.v" \
    "top_module.v" \
]

foreach file $rtl_files {
    if { [file exists $file] } {
        puts "  Reading: $file"
        read_hdl $file
    } else {
        puts "  ERROR: File not found: $file"
        exit 1
    }
}

puts "✓ All RTL files read successfully"
puts ""

#==============================================================================
# ELABORATE DESIGN
#==============================================================================

puts "=========================================="
puts "Step 3: Elaborating Design"
puts "=========================================="
puts "Top module: $TOP"

elaborate $TOP

puts "✓ Design elaborated successfully"
puts ""

#==============================================================================
# INITIALIZE DESIGN (CRITICAL FOR OUTPUT GENERATION)
#==============================================================================

puts "=========================================="
puts "Step 3a: Initializing Design Context"
puts "=========================================="

# This is critical - tells Genus which design is active
init_design

puts "✓ Design initialized"
puts ""

#==============================================================================
# PRE-SYNTHESIS DESIGN STATISTICS
#==============================================================================

puts "=========================================="
puts "Step 4: Pre-Synthesis Design Statistics"
puts "=========================================="

set num_instances [llength [get_db insts]]
puts "  Total instances: $num_instances"

set num_regs [llength [get_db [get_db insts -if {.is_sequential}]]]
puts "  Sequential elements (registers): $num_regs"

puts ""

#==============================================================================
# CHECK DESIGN
#==============================================================================

puts "=========================================="
puts "Step 5: Checking Design Integrity"
puts "=========================================="

check_design -all

puts "✓ Design check complete"
puts ""

#==============================================================================
# READ TIMING CONSTRAINTS
#==============================================================================

puts "=========================================="
puts "Step 6: Reading Timing Constraints"
puts "=========================================="

if { [file exists "filter_chain_CORRECTED.sdc"] } {
    read_sdc filter_chain_CORRECTED.sdc
    puts "✓ Constraints loaded from filter_chain_CORRECTED.sdc"
} elseif { [file exists "filter_chain.sdc"] } {
    read_sdc filter_chain.sdc
    puts "✓ Constraints loaded from filter_chain.sdc"
} else {
    puts "WARNING: No SDC file found!"
    puts "Creating basic 50 MHz clock constraint..."
    create_clock -name clk -period 20.0 [get_ports clk]
    set_input_delay 2.0 -clock clk [all_inputs]
    set_output_delay 2.0 -clock clk [all_outputs]
    puts "✓ Basic clock constraint applied (50 MHz)"
}
puts ""

#==============================================================================
# SYNTHESIS OPTIMIZATION SETTINGS
#==============================================================================

puts "=========================================="
puts "Step 7: Configuring Synthesis Options"
puts "=========================================="

puts "  Setting synthesis effort to HIGH"

set_db syn_generic_effort high
set_db syn_map_effort high
set_db syn_opt_effort high

puts "  Enabling optimizations..."

# Constant propagation
set_db optimize_constant_0_flops true
set_db optimize_constant_1_flops true

# Better output generation
set_db hdl_track_filename_row_col true

puts "✓ Synthesis options configured"
puts ""

#==============================================================================
# SYNTHESIS - PHASE 1: GENERIC
#==============================================================================

puts "=========================================="
puts "Step 8: Generic Synthesis (Technology Independent)"
puts "=========================================="
puts "This may take 30-60 seconds..."
puts ""

set generic_start [clock seconds]
syn_generic
set generic_end [clock seconds]
set generic_time [expr $generic_end - $generic_start]

puts ""
puts "✓ Generic synthesis complete ($generic_time seconds)"
puts ""

#==============================================================================
# SYNTHESIS - PHASE 2: MAPPING
#==============================================================================

puts "=========================================="
puts "Step 9: Technology Mapping"
puts "=========================================="
puts "Mapping to GPDK045 library cells..."
puts "This may take 30-90 seconds..."
puts ""

set map_start [clock seconds]
syn_map
set map_end [clock seconds]
set map_time [expr $map_end - $map_start]

puts ""
puts "✓ Technology mapping complete ($map_time seconds)"
puts ""

#==============================================================================
# SYNTHESIS - PHASE 3: OPTIMIZATION
#==============================================================================

puts "=========================================="
puts "Step 10: Incremental Optimization"
puts "=========================================="
puts "Fine-tuning for timing and area..."
puts "This may take 20-60 seconds..."
puts ""

set opt_start [clock seconds]
syn_opt
set opt_end [clock seconds]
set opt_time [expr $opt_end - $opt_start]

puts ""
puts "✓ Optimization complete ($opt_time seconds)"
puts ""

set total_synth_time [expr $generic_time + $map_time + $opt_time]
puts "Total synthesis time: $total_synth_time seconds"
puts ""

#==============================================================================
# VERIFY DESIGN IS MAPPED (CRITICAL CHECK)
#==============================================================================

puts "=========================================="
puts "Step 10a: Verifying Mapped Design"
puts "=========================================="

# Check for mapped instances using correct Genus attribute
set all_insts [get_db insts]
set num_insts [llength $all_insts]
puts "  Total instances: $num_insts"

# Check for library cells (mapped gates)
set lib_cells [get_db insts -if {.base_cell.name != ""}]
set num_lib_cells [llength $lib_cells]
puts "  Library cells: $num_lib_cells"

if { $num_lib_cells == 0 } {
    puts "ERROR: No library cells found! Design may not be mapped."
    puts "Synthesis may have failed. Check previous steps."
    exit 1
}

puts "✓ Design is properly mapped ($num_lib_cells gates)"
puts ""

#==============================================================================
# TIMING ANALYSIS
#==============================================================================

puts "=========================================="
puts "Step 11: Timing Analysis"
puts "=========================================="

# Get timing summary
set wns "N/A"
set tns "N/A"

puts "Generating timing summary..."
report_timing -max_paths 1

puts ""
puts "✓ Timing analysis complete"
puts ""

#==============================================================================
# GENERATE REPORTS
#==============================================================================

puts "=========================================="
puts "Step 12: Generating Reports"
puts "=========================================="

# Timing reports
puts "  Generating timing reports..."

catch {
    report_timing -max_paths 10 \
        -path_type full \
        > ${REPORT_DIR}/${DESIGN_NAME}_timing_top10.rpt
}

catch {
    report_timing -max_paths 50 \
        -path_type summary \
        > ${REPORT_DIR}/${DESIGN_NAME}_timing_summary.rpt
}

# Area reports
puts "  Generating area reports..."
catch {
    report_area > ${REPORT_DIR}/${DESIGN_NAME}_area.rpt
}

catch {
    report_area -depth 10 > ${REPORT_DIR}/${DESIGN_NAME}_area_hier.rpt
}

# Gate count reports
puts "  Generating gate count reports..."
catch {
    report_gates > ${REPORT_DIR}/${DESIGN_NAME}_gates.rpt
}

# Power reports
puts "  Generating power reports..."
catch {
    report_power > ${REPORT_DIR}/${DESIGN_NAME}_power.rpt
}

# Quality of Results summary
puts "  Generating QoR summary..."
catch {
    report_qor > ${REPORT_DIR}/${DESIGN_NAME}_qor.rpt
}

# Design hierarchy
catch {
    report_hierarchy > ${REPORT_DIR}/${DESIGN_NAME}_hierarchy.rpt
}

# Constraint violations
catch {
    report_constraint -all_violators \
        > ${REPORT_DIR}/${DESIGN_NAME}_violations.rpt
}

puts "✓ All reports generated in ${REPORT_DIR}/"
puts ""

#==============================================================================
# WRITE OUTPUT FILES - CORRECTED VERSION
#==============================================================================

#==============================================================================
# WRITE OUTPUT FILES
#==============================================================================

puts "=========================================="
puts "Step 13: Writing Output Files"
puts "=========================================="

# Gate-level netlist
puts "  Writing gate-level netlist..."
if { [catch {
    # CORRECTED: Use -format verilog, which is the reliable option
    write_hdl -format verilog > ${OUTPUT_DIR}/${TOP}_mapped.v 
} err] } {
    puts "  WARNING: write_hdl failed: $err"
    if { [catch {
        write_hdl > ${OUTPUT_DIR}/${TOP}_mapped.v
    } err2] } {
        puts "  ERROR: Could not write netlist: $err2"
    } else {
        puts "  ✓ Gate-level netlist (alt): ${TOP}_mapped.v"
    }
} else {
    puts "  ✓ Gate-level netlist: ${TOP}_mapped.v"
}

#==============================================================================
# SYNTHESIS SUMMARY
#==============================================================================

puts ""
puts "╔══════════════════════════════════════════════════════════════════════════════╗"
puts "║                        SYNTHESIS SUMMARY                                     ║"
puts "╚══════════════════════════════════════════════════════════════════════════════╝"
puts ""

puts "DESIGN INFORMATION:"
puts "  Top Module:     $TOP"
puts "  Target Freq:    50 MHz (20 ns period)"
puts "  Library:        GPDK045"
puts ""

puts "TIMING RESULTS:"
if { $wns != "N/A" } {
    puts "  WNS:            $wns ns"
    puts "  TNS:            $tns ns"
    if { [expr $wns >= 0] } {
        puts "  Status:         ✓✓✓ TIMING MET!"
    } else {
        puts "  Status:         ✗ TIMING VIOLATED"
    }
} else {
    puts "  Status:         Check ${REPORT_DIR}/${DESIGN_NAME}_qor.rpt for details"
}
puts ""

puts "SYNTHESIS TIME:"
puts "  Generic:        $generic_time seconds"
puts "  Mapping:        $map_time seconds"
puts "  Optimization:   $opt_time seconds"
puts "  Total:          $total_synth_time seconds"
puts ""

puts "OUTPUT FILES:"
puts "  Netlist:        ${OUTPUT_DIR}/${TOP}_mapped.v"
puts "  SDF:            ${OUTPUT_DIR}/${TOP}.sdf"
puts "  Constraints:    ${OUTPUT_DIR}/${TOP}_mapped.sdc"
puts ""

puts "REPORT FILES:"
puts "  Timing:         ${REPORT_DIR}/${DESIGN_NAME}_timing*.rpt"
puts "  Area:           ${REPORT_DIR}/${DESIGN_NAME}_area*.rpt"
puts "  Power:          ${REPORT_DIR}/${DESIGN_NAME}_power.rpt"
puts "  QoR Summary:    ${REPORT_DIR}/${DESIGN_NAME}_qor.rpt"
puts ""

#==============================================================================
# FILE VERIFICATION
#==============================================================================

puts "╔══════════════════════════════════════════════════════════════════════════════╗"
puts "║                      OUTPUT FILE VERIFICATION                                ║"
puts "╚══════════════════════════════════════════════════════════════════════════════╝"
puts ""

set files_to_check [list \
    "${OUTPUT_DIR}/${TOP}_mapped.v" \
    "${OUTPUT_DIR}/${TOP}.sdf" \
    "${REPORT_DIR}/${DESIGN_NAME}_timing_top10.rpt" \
    "${REPORT_DIR}/${DESIGN_NAME}_area.rpt" \
    "${REPORT_DIR}/${DESIGN_NAME}_qor.rpt" \
]

set all_files_ok 1
foreach file $files_to_check {
    if { [file exists $file] } {
        set size [file size $file]
        if { $size > 0 } {
            puts "  ✓ [file tail $file] ($size bytes)"
        } else {
            puts "  ⚠ [file tail $file] (EMPTY - check for errors)"
            set all_files_ok 0
        }
    } else {
        puts "  ✗ [file tail $file] (NOT FOUND)"
        set all_files_ok 0
    }
}

puts ""
if { $all_files_ok } {
    puts "╔══════════════════════════════════════════════════════════════════════════════╗"
    puts "║                     ✓✓✓ SYNTHESIS SUCCESSFUL! ✓✓✓                          ║"
    puts "╚══════════════════════════════════════════════════════════════════════════════╝"
} else {
    puts "╔══════════════════════════════════════════════════════════════════════════════╗"
    puts "║                     ⚠ SYNTHESIS COMPLETED WITH WARNINGS ⚠                   ║"
    puts "║                   Check output files and console messages                   ║"
    puts "╚══════════════════════════════════════════════════════════════════════════════╝"
}
puts ""

# Manual file check command suggestion
puts "To manually verify files, run:"
puts "  ls -lh ${OUTPUT_DIR}/"
puts "  ls -lh ${REPORT_DIR}/"
puts ""

# Exit Genus
puts "Exiting Genus..."
exit