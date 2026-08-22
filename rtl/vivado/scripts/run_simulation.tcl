# run_simulation.tcl
# Vivado Script to reproduce simulation

# 1. Create Project
create_project -force filter_sim_proj ./sim_build -part xc7s100fgga484-1

# 2. Add Design Sources
add_files [glob ../src/*.v]

# 3. Add Simulation Sources & Data
add_files -fileset sim_1 [glob ../tb/*.v]
add_files -fileset sim_1 ../tb/input_samples.txt
add_files -fileset sim_1 ../tb/coeffs_hex.txt

# 4. Set Top Modules
set_property top filter_chain_top [current_fileset]
set_property top tb_filter_chain [get_filesets sim_1]

# 5. Launch Simulation
launch_simulation
run 100 us