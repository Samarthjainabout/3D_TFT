# FeTFT DRAM-Like Dynamic Cell Simulink Model

This folder contains MATLAB/Simulink models for the 2T-2FeTFT DRAM-like dynamic-cell concept described in the reference document `FeTFT_DRAM_Like_Dynamic_Cell_Concept_and_Transfer_Function.docx`.

It is located in `tft3d_macros/sim/volatile_mode` so it can live alongside the existing TFT HSPICE and ngspice simulation assets without mixing generated volatile-mode files into the top-level `sim` folder.

The model is intentionally circuit-level and compact. It is not a replacement for the FeTFT Verilog-A/HSPICE device model. Its purpose is to make the proposed transfer-function assumptions executable and easy to sweep.

The NLS/detrapping retention mechanism is adapted from F. Mo et al., "Efficient Erase Operation by GIDL Current for 3D Structure FeFETs With Gate Stack Engineering and Compact Long-Term Retention Model," IEEE Journal of the Electron Devices Society, vol. 10, pp. 115-122, 2022, doi: 10.1109/JEDS.2022.3142046.

The NLS switching/retention audit also uses N. Gong, X. Sun, H. Jiang, K. S. Chang-Liao, Q. Xia, and T. P. Ma, "Nucleation limited switching (NLS) model for HfO2-based metal-ferroelectric-metal (MFM) capacitors: Switching kinetics and retention characteristics," Applied Physics Letters, vol. 112, 262903, 2018, doi: 10.1063/1.5010207.

The Preisach programming abstraction is adapted from K. Ni, M. Jerry, J. A. Smith, and S. Datta, "A Circuit Compatible Accurate Compact Model for Ferroelectric-FETs," 2018 IEEE Symposium on VLSI Technology, pp. 131-132, 2018.

## Source References Used

- `FeTFT_DRAM_Like_Dynamic_Cell_Concept_and_Transfer_Function.docx`: source for the 2T-2FeTFT bitcell topology, branch transfer functions, loop-gain condition, write/hold/read operating sequence, and retention-margin equation.
- F. Mo et al., "Efficient Erase Operation by GIDL Current for 3D Structure FeFETs With Gate Stack Engineering and Compact Long-Term Retention Model," IEEE Journal of the Electron Devices Society, vol. 10, pp. 115-122, 2022, doi: `10.1109/JEDS.2022.3142046`: source for the NLS-style time-dependent depolarization/back-switching retention mechanism and charge-detrapping acceleration concept.
- N. Gong, X. Sun, H. Jiang, K. S. Chang-Liao, Q. Xia, and T. P. Ma, "Nucleation limited switching (NLS) model for HfO2-based metal-ferroelectric-metal (MFM) capacitors: Switching kinetics and retention characteristics," Applied Physics Letters, vol. 112, 262903, 2018, doi: `10.1063/1.5010207`: source for the NLS domain-nucleation basis, pulse-width/amplitude switching kinetics, voltage-dependent characteristic switching times, and depolarization-field retention iteration.
- K. Ni, M. Jerry, J. A. Smith, and S. Datta, "A Circuit Compatible Accurate Compact Model for Ferroelectric-FETs," 2018 IEEE Symposium on VLSI Technology, pp. 131-132, 2018: source for the Preisach-based programming abstraction, including tanh saturation branches, history/minor-loop motivation, and RC effective-voltage switching delay.

## Files

- `build_fetft_dynamic_cell_model.m`: creates the Simulink model, sets simulation parameters, optionally runs the transient simulation, and saves results.
- `build_fetft_preisach_sequence_model.m`: creates a full write-hold-read Simulink sequence model with Preisach-style write programming followed by NLS retention.
- `build_fetft_recurrent_hybrid_model.m`: creates a repeated write-hold-read Simulink model where each WRITE starts from the state relaxed by the previous HOLD/READ interval.
- `build_fetft_transfer_function_diagram.m`: creates a Simulink transfer-function block diagram for the cross-coupled FeTFT branches.
- `fetft_cell_vector.m`: equation helper called by the generated Simulink model.
- `fetft_preisach_sequence_vector.m`: equation helper called by the full write-hold-read Preisach sequence model.
- `fetft_preisach_sequence_dataset.m`: generates the deterministic time/value matrix consumed by the full write-hold-read Simulink model.
- `fetft_recurrent_hybrid_dataset.m`: generates the deterministic repeated write-hold-read schedule consumed by the recurrent hybrid Simulink model.
- `run_fefet_combined_model_testbench.m`: runs the DOCX-derived combined-model verification cases against the current Simulink/MATLAB models.
- `run_fefet_paper_limited_testbench.m`: runs the paper-limited verification audit using only the attached Preisach and NLS papers as the source of requirements.
- `run_fetft_dynamic_cell_equations.py`: runs the same equations without MATLAB/Simulink for license-independent validation.
- `fetft_dram_like_dynamic_cell.slx`: generated Simulink model. Rebuild it by rerunning the MATLAB script.
- `fetft_preisach_write_hold_read.slx`: generated full write-hold-read sequence model using Preisach-style programming.
- `fetft_recurrent_hybrid_write_hold_read.slx`: generated recurrent hybrid sequence model with relaxed-state feedback into later writes.
- `fetft_preisach_sequence_results.mat`: generated full sequence simulation output.
- `fetft_preisach_sequence_response.png`: generated plot for the full sequence simulation.
- `fetft_recurrent_hybrid_results.mat`: generated recurrent hybrid simulation output.
- `fetft_recurrent_hybrid_response.png`: generated plot for the recurrent hybrid simulation.
- `fetft_combined_model_testbench_report.md`: generated pass/fail/partial report for the combined-model verification cases.
- `fetft_combined_model_testbench_results.csv`: generated machine-readable case status table.
- `fetft_combined_model_testbench_results.mat`: generated MATLAB testbench results and captured simulation outputs.
- `fetft_paper_limited_testbench_report.md`: generated pass/fail/partial report constrained to the attached Preisach and NLS papers.
- `fetft_paper_limited_testbench_results.csv`: generated machine-readable paper-limited status table.
- `fetft_paper_limited_testbench_results.mat`: generated MATLAB paper-limited audit results and captured simulation outputs.
- `fetft_transfer_function_block_diagram.slx`: generated transfer-function block-diagram model.
- `fetft_transfer_function_block_diagram.png`: exported image of the transfer-function block diagram.
- `fetft_transfer_function_results.mat`: generated transfer-function diagram simulation output.
- `fetft_dynamic_cell_results.mat`: generated simulation output when the script is run.
- `fetft_dynamic_cell_response.png`: generated plot of differential polarization, differential output voltage, and read margin.
- `fetft_dynamic_cell_equation_results.csv`: generated Python fallback output.
- `fetft_dynamic_cell_equation_response.png`: generated Python fallback plot when `matplotlib` is available.
- `fetft_dynamic_cell_equation_response.svg`: generated dependency-free fallback plot when `matplotlib` is not available.

## Modeled Equations

There are three time-domain models in this folder:

- `fetft_dram_like_dynamic_cell.slx`: the first retention simulation. It keeps the existing simplified write initializer and focuses on NLS/detrapping retention decay.
- `fetft_preisach_write_hold_read.slx`: the one-write handoff sequence model. It uses a reduced Preisach programming stage for WRITE, then applies the same NLS/detrapping retention decay during HOLD and READ.
- `fetft_recurrent_hybrid_write_hold_read.slx`: the recurrent hybrid sequence model. It repeats WRITE/HOLD/READ and feeds the relaxed HOLD/READ state back into the next Preisach WRITE.

## Interaction Between The Two Models

The Preisach and NLS models interact through the polarization state, not through a full self-consistent FeFET compact-model solve.

The first hybrid implementation deliberately avoids duplicating switching kinetics. Ni's Preisach compact-model paper already includes time-dependent programming through an RC-delayed effective ferroelectric voltage during WRITE. Therefore, this model does not run an additional NLS switching process on the same domains during the write pulse.

The one-write handoff model is:

```text
WRITE:
  Preisach programming model computes P17_write and P18_write.
  dPProgrammed = P17_write - P18_write

HOLD and READ:
  NLS/detrapping model computes retentionFactor(t).
  dP(t) = dPProgrammed * retentionFactor(t)

READ voltage:
  polarizationGain = B / (1 - a)
  DeltaV_Q(t) = polarizationGain * dP(t)
```

The recurrent hybrid model adds the return path:

```text
WRITE n:
  Preisach programming starts from the current relaxed P17 and P18 states.

HOLD/READ n:
  NLS/detrapping relaxation updates P17 and P18.

WRITE n + 1:
  The next Preisach branch starts from those relaxed P17 and P18 states.
```

That return path is the meaningful coupling in this reduced model. It is stronger than simply attaching a decay curve after a write because the decayed state changes the initial condition for later partial/minor-loop programming.

This interaction is appropriate for the current model scope because the two source papers cover different parts of the sequence. The Ni/Jerry/Smith/Datta Preisach model is used for programming history, partial switching, minor-loop behavior, and finite switching delay during WRITE. The Mo et al. retention model is used after programming, when the written ferroelectric state depolarizes or back-switches over time. Combining them as a staged model is therefore defensible for a bitcell-level write-hold-read abstraction.

The limitation is important: this is not yet a fully coupled FeFET compact model. A full compact model would solve MOS charge balance, FE voltage, Preisach history, trap charge, and circuit node voltages together at each time step. This simplified model intentionally uses Preisach only to establish the initial `dPProgrammed`, then uses NLS/detrapping as the volatile state-decay law.

A later unified model should use one calibrated kinetic law across WRITE and HOLD instead of applying separate programming and retention kinetics to the same domains over the same time interval.

The stored state is normalized differential polarization:

```text
dP = P17 - P18 = P_NF2 - P_NF1
P17 = P_EQ + dP/2
P18 = P_EQ - dP/2
```

In the first retention-only model, the simplified WRITE initializer creates a partial polarization difference:

```text
dP(t) = dP0 * (1 - exp(-t/tauWrite))
```

The HOLD and READ phases use an effective NLS-style depolarization/back-switching law based on the retention-model paper. The paper models retention by repeatedly updating the ferroelectric voltage and applying field-dependent NLS depolarization over short time steps. In this cell-level model, that mechanism is reduced to the stored differential polarization state:

```text
dP(t) = dP_write_end * exp(-Atrap(t) * ((t - tWrite)/tauNLS)^betaRetention)
Atrap(t) = 1 + trapAccel * (1 - exp(-(t - tWrite)/tauTrap))
```

This is not a full FeFET compact model. It is only an equivalent time-dependent state-decay mechanism for relaxation/back-switching/depolarization. The optional `Atrap(t)` multiplier captures the paper's observation that charge detrapping can accelerate retention degradation.

For the one-write handoff and recurrent hybrid models, WRITE instead uses a reduced Preisach programming approximation:

```text
Veff(t) = Vwrite * (1 - exp(-t/tauVeff))
F_up(Veff) = Ps * tanh(alpha * (Veff - Vc))
F_down(Veff) = Ps * tanh(alpha * (Veff + Vc))
P17_write = minorScale * [F_up(Veff17) - F_up(0)] / [Ps - F_up(0)]
P18_write = minorScale * [F_down(Veff18) - F_down(0)] / [Ps + F_down(0)]
DeltaP_write = P17_write - P18_write
```

The branch normalization makes the initial zero-bias programmed polarization equal to zero, while preserving the Preisach-style shifted tanh saturation branches. This keeps the core circuit-compatible ideas from the Preisach paper: a static saturation loop, branch-dependent programming direction, partial/minor-loop programming, and finite switching dynamics represented by an RC effective-voltage delay. The implementation is intentionally reduced to the state variables needed by this bitcell-level simulation.

The symmetric gain-cell approximation is represented as:

```text
DeltaV_Q = Gp * dP
Gp = B / (1 - a)
```

Here `a` is the effective regenerative factor, kept below one in every phase. `aHold` demonstrates the required `|L_FE(0)| < 1` hold condition. `aRead` is closer to one, representing `|L_FE(0)| -> 1-` for read amplification.

The retention estimate follows the reference margin equation:

```text
tR ~= tauNLS * [ln(Gp_read * |dP0| / V_MIN)]^(1/betaRetention)
```

The script computes this with the actual post-write `dP_write_end`.

## Default Demonstration Parameters

The defaults are normalized, illustrative values chosen to show the intended behavior:

- Write duration: `2 us`
- Read starts at: `22 us`
- Effective NLS retention time scale: `11 us`
- NLS shape factor: `betaRetention = 0.62`
- Detrapping acceleration: `trapAccel = 0.18`
- Detrapping time scale: `tauTrap = 25 us`
- Hold regenerative factor: `aHold = 0.35`
- Read regenerative factor: `aRead = 0.88`
- Read conversion coefficient: `bRead = 0.12 V`
- Sense threshold: `V_MIN = 0.12 V`

These are placeholders until extracted from FeTFT Verilog-A/HSPICE characterization.

## How To Run

From MATLAB:

```matlab
cd('D:\gitt\Open3DStack\pdk\tft3d_platform\libs.ref\tft3d_macros\sim\volatile_mode')
build_fetft_dynamic_cell_model
open_system('fetft_dram_like_dynamic_cell')
```

To rebuild the `.slx` without running the simulation:

```matlab
build_fetft_dynamic_cell_model(false)
```

To create the transfer-function block diagram:

```matlab
build_fetft_transfer_function_diagram
open_system('fetft_transfer_function_block_diagram')
```

To run the full write-hold-read sequence with Preisach-style write programming:

```matlab
build_fetft_preisach_sequence_model
open_system('fetft_preisach_write_hold_read')
```

To run the recurrent hybrid model with relaxed-state feedback into later writes:

```matlab
build_fetft_recurrent_hybrid_model
open_system('fetft_recurrent_hybrid_write_hold_read')
```

To run the combined-model verification cases from `FeFET_Combined_Model_Testbench.docx`:

```matlab
run_fefet_combined_model_testbench
```

To run the paper-limited audit derived only from the attached Preisach and NLS papers:

```matlab
run_fefet_paper_limited_testbench
```

If MATLAB licensing is unavailable, run the equation-level fallback from PowerShell:

```powershell
python D:\gitt\Open3DStack\pdk\tft3d_platform\libs.ref\tft3d_macros\sim\volatile_mode\run_fetft_dynamic_cell_equations.py
```

## Expected Output

The simulation should show:

- During WRITE, `dP` rises toward a partial differential polarization state.
- During HOLD, `dP` follows stretched-exponential NLS-style depolarization/back-switching.
- During READ, `DeltaV_Q` is amplified by the larger read gain while the loop gain remains below unity.
- `senseMargin` becomes negative when the remaining differential polarization can no longer support the chosen `V_MIN`.
- In the recurrent hybrid model, later writes start from the relaxed `P17` and `P18` values left by earlier HOLD/READ intervals.

The important causality check is that `DeltaV_Q` follows `dP`. If a future detailed circuit simulation shows `Q - Qbar` decaying while `P_NF2 - P_NF1` does not, the decay is likely electrical/RC-driven rather than ferroelectric-polarization-driven.
