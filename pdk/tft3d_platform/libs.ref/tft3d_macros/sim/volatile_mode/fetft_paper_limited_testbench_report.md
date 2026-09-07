# FeFET Paper-Limited Testbench Results

This report intentionally uses only the attached Preisach and NLS papers as the source of requirements. Requirements not present in those papers are marked `NOT_IN_PAPERS` and are not counted as pass/fail obligations.

Sources:
- K. Ni, M. Jerry, J. A. Smith, and S. Datta, "A Circuit Compatible Accurate Compact Model for Ferroelectric-FETs," 2018 IEEE Symposium on VLSI Technology, pp. 131-132, 2018.
- F. Mo et al., "Efficient Erase Operation by GIDL Current for 3D Structure FeFETs With Gate Stack Engineering and Compact Long-Term Retention Model," IEEE Journal of the Electron Devices Society, vol. 10, pp. 115-122, 2022, doi: 10.1109/JEDS.2022.3142046.
- N. Gong, X. Sun, H. Jiang, K. S. Chang-Liao, Q. Xia, and T. P. Ma, "Nucleation limited switching (NLS) model for HfO2-based metal-ferroelectric-metal (MFM) capacitors: Switching kinetics and retention characteristics," Applied Physics Letters, vol. 112, 262903, 2018, doi: 10.1063/1.5010207.

## Requested Nine-Item Audit

| Item | Requirement | Paper support | Model status | Evidence | Paper basis |
|---|---|---|---|---|---|
| I01 | Explicit domain fractions f_i | PARTIAL_IN_PAPERS | FAIL | The current model logs scalar P17/P18/dP only (max \|dP\| 1.533); it does not expose NLS domain population fractions. | Gong supports a multiple-domain NLS picture and switched-polarization fraction versus pulse duration, but the exact f_i state-vector interface is not stated. |
| I02 | Per-domain rates r_i_plus and r_i_minus | NOT_IN_PAPERS | NOT_COUNTED | The exact bidirectional rate-state equation is not present in the attached papers. | Gong gives voltage-dependent characteristic switching times and switched-polarization relationships; it does not state a per-domain r_i_plus/r_i_minus ODE interface. |
| I03 | Fixed-rate override for analytic oracle tests | NOT_IN_PAPERS | NOT_COUNTED | A fixed-rate debug oracle is a testbench feature, not a requirement stated by either paper. | No paper basis found for bypassing the model with constant rates. |
| I04 | retention_enable and programming_enable freeze controls | NOT_IN_PAPERS | NOT_COUNTED | Enable/freeze switches are useful verification controls, but they are not specified in the two papers. | No paper basis found for software ownership freeze controls. |
| I05 | Hold-field controls such as K_dep, E_hold, and E_imp | PARTIAL_IN_PAPERS | FAIL | HOLD retention changes over time (min factor 0.204), but the current outputs have no V_FE/E_dep/E_hold field-control state. | Mo and Gong support depolarization-field-driven retention, but the specific K_dep/E_hold/E_imp knobs are not named in the attached papers. |
| I06 | Full Preisach history import/export | PARTIAL_IN_PAPERS | PARTIAL | Reduced scalar state handoff exists, but no Preisach turning-point/history object is logged. handoff 24.00 us error 0 handoff 48.00 us error 0.000626 | Ni requires history and minor-loop trajectory tracking; import/export itself is not specified in the paper. |
| I07 | Long-time checkpoint/save/restore test harness | NOT_IN_PAPERS | NOT_COUNTED | Checkpoint and restore are simulation workflow features, not physical model requirements in the two papers. | No paper basis found for Simulink operating-point checkpoint tests. |
| I08 | Retention-disabled overlay sweeps | NOT_IN_PAPERS | NOT_COUNTED | Retention-disabled overlays are a validation convenience; they are not stated in either paper as a model requirement. | No paper basis found for this exact overlay test. |
| I09 | Standalone Preisach reference comparison across amplitude, width, and history | PARTIAL_IN_PAPERS | PARTIAL | A single finite pulse sequence exercises amplitude/time response (max \|Veff\| 2.398 V, max \|dP\| 1.546), but no amplitude/width/history sweep or standalone reference overlay is run. | Ni demonstrates dependence on amplitude, pulse width, and history. A standalone Simulink-vs-reference harness is not directly specified. |

## Core Paper-Derived Behavior

| Item | Requirement | Paper support | Model status | Evidence | Paper basis |
|---|---|---|---|---|---|
| CORE01 | Preisach WRITE and NLS retention staged ownership | IN_PAPERS | PASS | During WRITE, retentionFactor stays at 1 with max error 0; during HOLD it decays to 0.204. | Mo explicitly uses Preisach for initialization/program/erase and NLS for retention state. |
| CORE02 | Retention decay after programmed state | IN_PAPERS | PASS | Positive retention decay ok=1, \|dP\| 1.533 -> 0.2211. Negative retention decay ok=1, \|dP\| 1.531 -> 0.2208. | Mo attributes long-term retention degradation to NLS depolarization and detrapping effects. |
| CORE03 | NLS retention decreases depolarization drive as polarization decays | IN_PAPERS | PASS | In HOLD, \|dP\| decreases from 1.533 to 0.09365 while retentionFactor decreases from 1 to 0.4241. | Gong states that during retention no external voltage is applied, the only field is the depolarization field, and that field drops with gradually reduced polarization. |

## Counts

- Requested paper-supported items: PASS=0, PARTIAL=2, FAIL=2, NOT_IN_PAPERS=5
- Core paper-derived behavior checks: PASS=3, PARTIAL=0, FAIL=0
