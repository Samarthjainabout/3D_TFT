# FeFET Paper-Limited Testbench Results

This report intentionally uses only the attached Preisach and NLS papers as the source of requirements. Requirements not present in those papers are marked `NOT_IN_PAPERS` and are not counted as pass/fail obligations.

Sources:
- K. Ni, M. Jerry, J. A. Smith, and S. Datta, "A Circuit Compatible Accurate Compact Model for Ferroelectric-FETs," 2018 IEEE Symposium on VLSI Technology, pp. 131-132, 2018.
- F. Mo et al., "Efficient Erase Operation by GIDL Current for 3D Structure FeFETs With Gate Stack Engineering and Compact Long-Term Retention Model," IEEE Journal of the Electron Devices Society, vol. 10, pp. 115-122, 2022, doi: 10.1109/JEDS.2022.3142046.
- N. Gong, X. Sun, H. Jiang, K. S. Chang-Liao, Q. Xia, and T. P. Ma, "Nucleation limited switching (NLS) model for HfO2-based metal-ferroelectric-metal (MFM) capacitors: Switching kinetics and retention characteristics," Applied Physics Letters, vol. 112, 262903, 2018, doi: 10.1063/1.5010207.

## Requested Nine-Item Audit

| Item | Requirement | Paper support | Model status | Evidence | Paper basis |
|---|---|---|---|---|---|
| I01 | Explicit domain fractions f_i | PARTIAL_IN_PAPERS | PASS | Eight f_i bins per FeTFT branch are logged; f range 0..1, reconstruction errors P17=0 and P18=0. | Gong supports a multiple-domain NLS picture and switched-polarization fraction versus pulse duration, but the exact f_i state-vector interface is not stated. |
| I02 | Per-domain rates r_i_plus and r_i_minus | PARTIAL_IN_PAPERS | PASS | Per-domain equivalent NLS rates are logged; max hold/read rate 9.872e+05 s^-1 and max write rate 0 s^-1. | Mo and Gong support NLS retention over short intervals with voltage/depolarization-field-dependent characteristic switching times. The exact r_i_plus/r_i_minus ODE notation is an implementation interface. |
| I03 | Fixed-rate override for analytic oracle tests | NOT_IN_PAPERS | NOT_COUNTED | A fixed-rate debug oracle is a testbench feature, not a requirement stated by either paper. | No paper basis found for bypassing the model with constant rates. |
| I04 | retention_enable and programming_enable freeze controls | NOT_IN_PAPERS | NOT_COUNTED | Enable/freeze switches are useful verification controls, but they are not specified in the two papers. | No paper basis found for software ownership freeze controls. |
| I05 | Hold-field controls such as K_dep, E_hold, and E_imp | PARTIAL_IN_PAPERS | PASS | HOLD retention changes over time (min factor 0.1594) while V_FE/E_dep/E_hold/E_imp terms are logged; max \|V_FE\| in hold is 0.7664. | Mo and Gong support depolarization-field-driven retention, but the specific K_dep/E_hold/E_imp knobs are not named in the attached papers. |
| I06 | Full Preisach history import/export | PARTIAL_IN_PAPERS | PASS | Serializable branch/turning-point/depth history fields are logged; max history depth 0.8858. handoff 24.00 us error 0 handoff 48.00 us error 4.12e-05 | Ni requires history and minor-loop trajectory tracking; import/export itself is not specified in the paper. |
| I07 | Long-time checkpoint/save/restore test harness | NOT_IN_PAPERS | NOT_COUNTED | Checkpoint and restore are simulation workflow features, not physical model requirements in the two papers. | No paper basis found for Simulink operating-point checkpoint tests. |
| I08 | Retention-disabled overlay sweeps | NOT_IN_PAPERS | NOT_COUNTED | Retention-disabled overlays are a validation convenience; they are not stated in either paper as a model requirement. | No paper basis found for this exact overlay test. |
| I09 | Standalone Preisach reference comparison across amplitude, width, and history | PARTIAL_IN_PAPERS | PASS | Simulink sequence is finite (max \|Veff\| 2.398 V, max \|dP\| 1.546). Standalone Preisach sweep: 54 cases, 3 amplitudes, 3 widths, 3 starts, max error 0, unsaturated=1. | Ni demonstrates dependence on amplitude, pulse width, and history. A standalone Simulink-vs-reference harness is not directly specified. |

## Core Paper-Derived Behavior

| Item | Requirement | Paper support | Model status | Evidence | Paper basis |
|---|---|---|---|---|---|
| CORE01 | Preisach WRITE and NLS retention staged ownership | IN_PAPERS | PASS | During WRITE, retentionFactor stays at 1 with max error 0; during HOLD it decays to 0.1594. | Mo explicitly uses Preisach for initialization/program/erase and NLS for retention state. |
| CORE02 | Retention decay after programmed state | IN_PAPERS | PASS | Positive retention decay ok=1, \|dP\| 1.533 -> 0.241. Negative retention decay ok=1, \|dP\| 1.531 -> 0.2409. | Mo attributes long-term retention degradation to NLS depolarization and detrapping effects. |
| CORE03 | NLS retention decreases depolarization drive as polarization decays | IN_PAPERS | PASS | In HOLD, \|dP\| decreases from 1.533 to 0.2301 while retentionFactor decreases from 1 to 0.9557. | Gong states that during retention no external voltage is applied, the only field is the depolarization field, and that field drops with gradually reduced polarization. |

## Counts

- Requested paper-supported items: PASS=5, PARTIAL=0, FAIL=0, NOT_IN_PAPERS=4
- Core paper-derived behavior checks: PASS=3, PARTIAL=0, FAIL=0
