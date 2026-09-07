# FeFET Combined Model Testbench Results

External test specification: `C:\Users\elesamj\Downloads\FeFET_Combined_Model_Testbench.docx`

This report tests the current reduced Simulink/MATLAB implementation. The DOCX is treated as an external test specification, not as executable model instructions.

| Case | Status | Evidence | Missing or fail reason |
|---|---|---|---|
| TC01 | FAIL | Frozen-state and zero-field retention controls are not exposed. | Missing separate state-update enables, retention_enable, and zero-field K_dep/E_hold/E_imp controls. |
| TC02 | FAIL | Constant-rate analytic oracle cannot be driven through the current model. | Missing domain fraction f_i logging, N-domain configuration, fixed-rate override, and depolarization-feedback disable. |
| TC03 | PARTIAL | One-write Preisach sequence runs with finite traces; max \|Veff\| = 2.4 V and max \|dP\| = 1.55. | Full pass still requires standalone Preisach reference overlay across amplitudes, widths, history states, and retention-disabled controls. |
| TC04 | PARTIAL | Positive hold/read sign+decay=1, \|dP\| 1.533 -> 0.2211, max upward step 0. Negative hold/read sign+decay=1, \|dP\| 1.531 -> 0.2208, max upward step 0. | Retention-disabled control and individual domain-rate ordering are not implemented. |
| TC05 | FAIL | No-op HOLD->WRITE->HOLD handoff without a write pulse is not represented by the generated sequence. | Missing mode ownership switch with both update paths frozen and same-time f_i/P handoff checker. |
| TC06 | PARTIAL | Write near 24.00 us consumes relaxed state with max start-state error 0 (P17 0.1105 -> 0.1105, P18 -0.1105 -> -0.1105). Write near 48.00 us consumes relaxed state with max start-state error 0.000626 (P17 -0.111 -> -0.1104, P18 0.111 -> 0.1104). | Full pass requires waits of 1 us, 1 ms, and 100 s plus isolated programming replay from the same complete domain/history state. |
| TC07 | PARTIAL | Included repeated sequence reverses sign: dP at 26 us = -1.531, dP at 50 us = 1.531. | Full pass requires a partial opposite-polarity pulse followed by verified full erase and polarity-reversed mirror run. |
| TC08 | FAIL | Intermediate scalar P states can be scheduled, but complete domain populations and Preisach history are not saved or replayed. | Missing f_i arrays, turning-point/history state, and same-complete-state replay checks. |
| TC09 | FAIL | Depolarization and hold-field controls are not parameters in the current reduced retention law. | Missing K_dep, E_hold, E_imp, compensation-field, and initial-rate sign checks. |
| TC10 | FAIL | The current model stores a scalar polarization pair, not multiple domain populations with identical net P. | Missing N=2 domain injection, per-domain rates, and derivative oracle. |
| TC11 | PARTIAL | READ phase produces finite dVQ and no large dP reset at first read boundary; \|jump22\|=0.0108, \|jump46\|=0.000846. | Full pass requires a no-read versus ideal-observation comparison and explicit finite read-voltage pulse-rate modeling. |
| TC12 | PARTIAL | Representative Simulink runs are finite. max recurrent \|dP\| = 1.533; max one-write \|dP\| = 1.546. | Full pass requires tighter tolerance reruns, segmented-vs-continuous hold, complete save/restore, and long-time stress. |
| E2E01 | FAIL | The current recurrent sequence covers repeated write-hold-read sign reversal on a microsecond schedule. | The DOCX end-to-end sequence also requires negative conditioning before positive write, 1 ms and 100 s holds, frozen no-op handoff, partial positive pulse after long hold, negative erase, and retention-disabled overlay. |
