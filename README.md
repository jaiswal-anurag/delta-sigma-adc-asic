# Delta-Sigma ADC ASIC Development

**Team 42 · Inter IIT Tech Meet 14.0 · ISRO Problem Statement**

System-level modeling, decimation filter design, and RTL implementation of a high-resolution Delta-Sigma ADC targeting space-grade precision instrumentation applications (>16-bit ENOB).

## Overview

Three third-order Delta-Sigma modulator architectures were modeled and compared:

| Architecture | ENOB (bits) | SINAD (dB) | Notes |
|---|---|---|---|
| **DT (Discrete-Time)** | **21.03** | **128.39** | Selected — best predictability, lowest jitter sensitivity |
| CT (Continuous-Time) | 16.00 | 98.11 | Better high-bandwidth/low-power tradeoff, harder to verify |
| Hybrid CT-DT | 16.43 | 100.69 | Combined characteristics, highest design complexity |

The DT architecture was carried forward into decimation filter design, where a proposed CIC → halfband FIR → bandpass FIR chain was benchmarked against a conventional CIC → FIR-compensation → SINC chain:

| Decimation Chain | ENOB (bits) | SINAD (dB) | THD (dB) |
|---|---|---|---|
| SINC-based (baseline) | 17.07 | 104.52 | -81.96 |
| **FIR-based (proposed)** | **22.46** | **136.96** | **-115.40** |

Coefficient quantization studies showed performance saturates around 14-bit precision; 16-bit fixed-point was chosen as the hardware-cost/accuracy tradeoff for the RTL implementation.

## Repository Structure

```
.
├── docs/
│   └── End_Term_Report.pdf        # Full report (methodology, derivations, results)
├── matlab-simulink/
│   ├── CT/                        # Continuous-time modulator model
│   ├── CTDT/                      # Hybrid CT-DT modulator model
│   ├── DT/                        # Discrete-time modulator + RTL verification scripts
│   └── DT_model_2filters/         # SINC vs. FIR decimation chain comparison
├── rtl/
│   ├── src/                       # Synthesizable Verilog source
│   │   ├── cic.v                  # Stage 1: CIC decimator (R=64, Hogenauer structure)
│   │   ├── fir.v                  # Stage 2: FIR decimator (R=2, droop compensation)
│   │   ├── iir.v                  # Stage 3: IIR bandpass/highpass (DC removal)
│   │   └── top_module.v           # filter_chain_top — connects the three stages
│   ├── tb/
│   │   ├── tb_filter_chain.v       # File-based testbench (drives d_in, checks d_out)
│   │   ├── input_samples.txt       # Modulator bitstream vectors (from MATLAB reference)
│   │   └── coeffs_hex.txt          # FIR/IIR coefficients in hex
│   ├── vivado/                    # FPGA-target flow (Xilinx Vivado, xc7s100fgga484-1)
│   │   ├── constraints/timing.xdc  # 10 MHz clock constraint
│   │   ├── scripts/run_simulation.tcl
│   │   └── reports/                # Vivado timing_summary.txt, utilization_1.txt
│   ├── netlist/
│   │   └── filter_chain_top_mapped.v   # Post-synthesis gate-level netlist (Cadence Genus)
│   └── synthesis/                  # ASIC flow (Cadence Genus, GPDK045)
│       ├── filter.tcl                  # Genus synthesis script (GPDK045, 50 MHz target)
│       ├── filter_chain_CORRECTED.sdc  # Timing constraints
│       └── *.rpt                       # Area, timing, power, QoR, gate, hierarchy reports
└── README.md
```

> **Known issue:** `filter_chain_area.rpt` / `filter_chain_qor.rpt` (Genus/ASIC flow) report 0.000 for all cell/net area — the library linked at synthesis time didn't carry real physical/area data (timing numbers are populated and valid). Don't quote area figures from that run; re-synthesize with a proper `.lib` if you need real ASIC area numbers. FPGA-side utilization numbers (`rtl/vivado/reports/utilization_1.txt`) are real and match the report.

## Requirements

- MATLAB R2021b or later
- Simulink
- Signal Processing Toolbox (FFT-based SINAD/ENOB estimation)

## Running the Models

Each model folder follows the same pattern — **run the initialization script before opening the `.slx` file**, or Simulink will throw undefined-variable errors (`b_fir`, `num`, `den`, etc.):

1. `cd matlab-simulink/DT` (or `CT`, `CTDT`, `DT_model_2filters`)
2. Run `initialize_parameters_DT.m` (loads modulator/filter coefficients)
3. Open and run `Modulator_DT.slx` (stop time ≥ 1.0 s recommended — the FFT needs >4096 samples)
4. Run `enob_calculator.m` to compute SINAD/ENOB from the simulation output

`DT/` additionally contains scripts to validate RTL output against the MATLAB reference:
- `calculating_enob_from_rtl.m` — parses RTL-generated output text files and computes ENOB
- `regenrating_sine_wave_from_rtl.m` — reconstructs the analog waveform from the RTL bitstream

## Key Design Parameters

- Sampling frequency: 256 kHz, OSR = 128, signal bandwidth = 1 kHz
- Modulator: 3rd-order, 1-bit quantizer
- Decimation: CIC (R=64, N=4) → 51-tap halfband FIR → 2nd-order IIR bandpass (80–990 Hz)
- Target synthesis: 10 MHz max oversampling clock, 16-bit fixed-point FIR coefficients

## Synthesis Results

**FPGA (Xilinx Vivado, xc7s100fgga484-1, 10 MHz clock):**

| Metric | Value |
|---|---|
| WNS (setup) | +86.592 ns (met) |
| WHS (hold) | +0.139 ns (met) |
| Slice LUTs | 553 / 64,000 (0.86%) |
| Slice Registers | 91 / 128,000 (0.07%) |
| DSP48E1 | 2 / 160 |

**ASIC (Cadence Genus, GPDK045, 50 MHz clock):**

| Metric | Value |
|---|---|
| Clock period | 20.0 ns (50 MHz) |
| WNS | +14.940 ns (met) |
| Critical path delay | 4.030 ns (`iir` module) |
| Total leaf instances | 9,520 (cic: 1,020 · fir: 6,891 · iir: 1,609) |
| Sequential instances | 1,169 |
| Combinational instances | 8,351 |

FIR decimator dominates instance count (~72%), consistent with the 51-tap MAC structure described in the report.

## Running the RTL Simulation

```bash
cd rtl/vivado/scripts
vivado -mode tcl -source run_simulation.tcl
```

This creates a Vivado project, adds `rtl/src/*.v` as design sources and `rtl/tb/*.v` (+ `input_samples.txt`, `coeffs_hex.txt`) as simulation sources, sets `filter_chain_top` / `tb_filter_chain` as top modules, and runs 100 µs of simulation.

## Team

Team ID 42 — Inter IIT Tech Meet 14.0, ISRO problem statement.

## License

Add a license (MIT/Apache-2.0/etc.) if this is meant to be public. Competition IP rules may apply — check with your team/ISRO POC before choosing a license or making the repo public.
