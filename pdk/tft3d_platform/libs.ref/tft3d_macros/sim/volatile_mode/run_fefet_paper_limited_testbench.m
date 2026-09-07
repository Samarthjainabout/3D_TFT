function results = run_fefet_paper_limited_testbench()
%RUN_FEFET_PAPER_LIMITED_TESTBENCH Test only requirements supported by papers.
%
% Sources used for the paper-support audit:
%   - K. Ni, M. Jerry, J. A. Smith, and S. Datta, "A Circuit Compatible
%     Accurate Compact Model for Ferroelectric-FETs," 2018 IEEE Symposium
%     on VLSI Technology, pp. 131-132, 2018.
%   - F. Mo et al., "Efficient Erase Operation by GIDL Current for 3D
%     Structure FeFETs With Gate Stack Engineering and Compact Long-Term
%     Retention Model," IEEE Journal of the Electron Devices Society,
%     vol. 10, pp. 115-122, 2022, doi: 10.1109/JEDS.2022.3142046.
%   - N. Gong et al., "Nucleation limited switching (NLS) model for
%     HfO2-based metal-ferroelectric-metal (MFM) capacitors: Switching
%     kinetics and retention characteristics," Applied Physics Letters,
%     vol. 112, 262903, 2018, doi: 10.1063/1.5010207.
%
% Requirements not present in those papers are marked NOT_IN_PAPERS and
% are not counted as Simulink pass/fail obligations.

thisDir = fileparts(mfilename('fullpath'));
oldDir = pwd;
cleanup = onCleanup(@() cd(oldDir));
cd(thisDir);

reportFile = fullfile(thisDir, 'fetft_paper_limited_testbench_report.md');
csvFile = fullfile(thisDir, 'fetft_paper_limited_testbench_results.csv');
matFile = fullfile(thisDir, 'fetft_paper_limited_testbench_results.mat');

fprintf('Running paper-limited Simulink/MATLAB checks...\n');
recurrentOut = build_fetft_recurrent_hybrid_model(true);
sequenceOut = build_fetft_preisach_sequence_model(true);

recurrent = collectSignals(recurrentOut, { ...
    'phase', 'writeCommand', 'pStart17', 'pStart18', 'p17', 'p18', ...
    'dPProgrammed', 'retentionFactor', 'dP', 'dVQ', 'senseMargin'});
sequence = collectSignals(sequenceOut, { ...
    'phase', 'vEff17', 'vEff18', 'p17Preisach', 'p18Preisach', ...
    'dPProgrammed', 'retentionFactor', 'p17', 'p18', 'dP', ...
    'polarizationGain', 'dVQ', 'loopGain', 'senseMargin'});

rows = {};
rows = addRow(rows, 'I01', 'Explicit domain fractions f_i', ...
    'PARTIAL_IN_PAPERS', i01Status(recurrent), ...
    i01Evidence(recurrent), ...
    'Gong supports a multiple-domain NLS picture and switched-polarization fraction versus pulse duration, but the exact f_i state-vector interface is not stated.');
rows = addRow(rows, 'I02', 'Per-domain rates r_i_plus and r_i_minus', ...
    'NOT_IN_PAPERS', 'NOT_COUNTED', ...
    'The exact bidirectional rate-state equation is not present in the attached papers.', ...
    'Gong gives voltage-dependent characteristic switching times and switched-polarization relationships; it does not state a per-domain r_i_plus/r_i_minus ODE interface.');
rows = addRow(rows, 'I03', 'Fixed-rate override for analytic oracle tests', ...
    'NOT_IN_PAPERS', 'NOT_COUNTED', ...
    'A fixed-rate debug oracle is a testbench feature, not a requirement stated by either paper.', ...
    'No paper basis found for bypassing the model with constant rates.');
rows = addRow(rows, 'I04', 'retention_enable and programming_enable freeze controls', ...
    'NOT_IN_PAPERS', 'NOT_COUNTED', ...
    'Enable/freeze switches are useful verification controls, but they are not specified in the two papers.', ...
    'No paper basis found for software ownership freeze controls.');
rows = addRow(rows, 'I05', 'Hold-field controls such as K_dep, E_hold, and E_imp', ...
    'PARTIAL_IN_PAPERS', i05Status(recurrent), ...
    i05Evidence(recurrent), ...
    'Mo and Gong support depolarization-field-driven retention, but the specific K_dep/E_hold/E_imp knobs are not named in the attached papers.');
rows = addRow(rows, 'I06', 'Full Preisach history import/export', ...
    'PARTIAL_IN_PAPERS', i06Status(recurrent), ...
    i06Evidence(recurrent), ...
    'Ni requires history and minor-loop trajectory tracking; import/export itself is not specified in the paper.');
rows = addRow(rows, 'I07', 'Long-time checkpoint/save/restore test harness', ...
    'NOT_IN_PAPERS', 'NOT_COUNTED', ...
    'Checkpoint and restore are simulation workflow features, not physical model requirements in the two papers.', ...
    'No paper basis found for Simulink operating-point checkpoint tests.');
rows = addRow(rows, 'I08', 'Retention-disabled overlay sweeps', ...
    'NOT_IN_PAPERS', 'NOT_COUNTED', ...
    'Retention-disabled overlays are a validation convenience; they are not stated in either paper as a model requirement.', ...
    'No paper basis found for this exact overlay test.');
rows = addRow(rows, 'I09', 'Standalone Preisach reference comparison across amplitude, width, and history', ...
    'PARTIAL_IN_PAPERS', i09Status(sequence), ...
    i09Evidence(sequence), ...
    'Ni demonstrates dependence on amplitude, pulse width, and history. A standalone Simulink-vs-reference harness is not directly specified.');

coreRows = {};
coreRows = addRow(coreRows, 'CORE01', 'Preisach WRITE and NLS retention staged ownership', ...
    'IN_PAPERS', core01Status(recurrent), ...
    core01Evidence(recurrent), ...
    'Mo explicitly uses Preisach for initialization/program/erase and NLS for retention state.');
coreRows = addRow(coreRows, 'CORE02', 'Retention decay after programmed state', ...
    'IN_PAPERS', core02Status(recurrent), ...
    core02Evidence(recurrent), ...
    'Mo attributes long-term retention degradation to NLS depolarization and detrapping effects.');
coreRows = addRow(coreRows, 'CORE03', 'NLS retention decreases depolarization drive as polarization decays', ...
    'IN_PAPERS', core03Status(recurrent), ...
    core03Evidence(recurrent), ...
    'Gong states that during retention no external voltage is applied, the only field is the depolarization field, and that field drops with gradually reduced polarization.');

results = cell2table(rows, 'VariableNames', ...
    {'ItemId', 'Requirement', 'PaperSupport', 'ModelStatus', 'Evidence', 'PaperBasis'});
coreResults = cell2table(coreRows, 'VariableNames', ...
    {'ItemId', 'Requirement', 'PaperSupport', 'ModelStatus', 'Evidence', 'PaperBasis'});

writeReport(reportFile, results, coreResults);
writetable(results, csvFile);
save(matFile, 'results', 'coreResults', 'recurrentOut', 'sequenceOut');

fprintf('Wrote report: %s\n', reportFile);
fprintf('Wrote CSV:    %s\n', csvFile);
fprintf('Wrote MAT:    %s\n', matFile);
disp(results(:, {'ItemId', 'PaperSupport', 'ModelStatus'}));
fprintf('Paper-supported requested items: PASS=%d, PARTIAL=%d, FAIL=%d, NOT_IN_PAPERS=%d\n', ...
    countStatus(results, 'PASS'), countStatus(results, 'PARTIAL'), ...
    countStatus(results, 'FAIL'), sum(strcmp(results.PaperSupport, 'NOT_IN_PAPERS')));
disp(coreResults(:, {'ItemId', 'PaperSupport', 'ModelStatus'}));
fprintf('Core paper-derived behavior: PASS=%d, PARTIAL=%d, FAIL=%d\n', ...
    sum(strcmp(coreResults.ModelStatus, 'PASS')), ...
    sum(strcmp(coreResults.ModelStatus, 'PARTIAL')), ...
    sum(strcmp(coreResults.ModelStatus, 'FAIL')));
end

function status = i01Status(data)
hasExplicitDomainState = isfield(data, 'f') || isfield(data, 'domainFraction') || isfield(data, 'domainFractions');
if hasExplicitDomainState
    status = 'PASS';
else
    status = 'FAIL';
end
end

function evidence = i01Evidence(data)
maxDP = max(abs(data.dP.values));
evidence = sprintf('The current model logs scalar P17/P18/dP only (max |dP| %.4g); it does not expose NLS domain population fractions.', maxDP);
end

function data = collectSignals(simOut, names)
data = struct();
for idx = 1:numel(names)
    item = simOut.get(names{idx});
    data.(names{idx}).time = item.time(:);
    data.(names{idx}).values = item.signals.values(:);
end
end

function rows = addRow(rows, itemId, requirement, paperSupport, modelStatus, evidence, paperBasis)
rows(end + 1, :) = {itemId, requirement, paperSupport, modelStatus, evidence, paperBasis};
end

function status = i05Status(data)
phase = data.phase.values;
hasHold = any(phase == 2);
retentionChanges = min(data.retentionFactor.values(phase == 2)) < 0.99;
hasFieldControl = isfield(data, 'vFeHold') || isfield(data, 'eDep') || isfield(data, 'eHold');
if hasHold && retentionChanges && hasFieldControl
    status = 'PASS';
elseif hasHold && retentionChanges
    status = 'FAIL';
else
    status = 'FAIL';
end
end

function evidence = i05Evidence(data)
phase = data.phase.values;
minRetention = min(data.retentionFactor.values(phase == 2));
evidence = sprintf('HOLD retention changes over time (min factor %.4g), but the current outputs have no V_FE/E_dep/E_hold field-control state.', minRetention);
end

function status = i06Status(data)
[ok24, ~] = returnedStateCheck(data, 24e-6);
[ok48, ~] = returnedStateCheck(data, 48e-6);
if ok24 && ok48
    status = 'PARTIAL';
else
    status = 'FAIL';
end
end

function evidence = i06Evidence(data)
[~, e24] = returnedStateCheck(data, 24e-6);
[~, e48] = returnedStateCheck(data, 48e-6);
evidence = sprintf('Reduced scalar state handoff exists, but no Preisach turning-point/history object is logged. %s %s', e24, e48);
end

function status = i09Status(data)
finite = all(isfinite(data.vEff17.values)) && all(isfinite(data.dP.values));
hasPulseEffect = max(abs(data.vEff17.values)) > 0.1 && max(abs(data.dP.values)) > 0.1;
if finite && hasPulseEffect
    status = 'PARTIAL';
else
    status = 'FAIL';
end
end

function evidence = i09Evidence(data)
maxVeff = max(max(abs(data.vEff17.values)), max(abs(data.vEff18.values)));
maxDP = max(abs(data.dP.values));
evidence = sprintf('A single finite pulse sequence exercises amplitude/time response (max |Veff| %.4g V, max |dP| %.4g), but no amplitude/width/history sweep or standalone reference overlay is run.', maxVeff, maxDP);
end

function status = core01Status(data)
phase = data.phase.values;
rf = data.retentionFactor.values;
writeOwns = all(abs(rf(phase == 1) - 1.0) < 1e-9);
holdOwns = min(rf(phase == 2)) < 0.99;
if writeOwns && holdOwns
    status = 'PASS';
else
    status = 'FAIL';
end
end

function evidence = core01Evidence(data)
phase = data.phase.values;
writeMaxErr = max(abs(data.retentionFactor.values(phase == 1) - 1.0));
holdMin = min(data.retentionFactor.values(phase == 2));
evidence = sprintf('During WRITE, retentionFactor stays at 1 with max error %.3g; during HOLD it decays to %.4g.', writeMaxErr, holdMin);
end

function status = core02Status(data)
[posOk, ~, ~, ~] = absDecayCheck(data, 2e-6, 24e-6, +1);
[negOk, ~, ~, ~] = absDecayCheck(data, 26e-6, 48e-6, -1);
if posOk && negOk
    status = 'PASS';
else
    status = 'FAIL';
end
end

function status = core03Status(data)
phase = data.phase.values;
dP = abs(data.dP.values(phase == 2));
retention = data.retentionFactor.values(phase == 2);
if isempty(dP) || isempty(retention)
    status = 'FAIL';
    return;
end
trendOk = dP(end) < dP(1) && retention(end) < retention(1);
if trendOk
    status = 'PASS';
else
    status = 'FAIL';
end
end

function evidence = core03Evidence(data)
phase = data.phase.values;
dP = abs(data.dP.values(phase == 2));
retention = data.retentionFactor.values(phase == 2);
evidence = sprintf('In HOLD, |dP| decreases from %.4g to %.4g while retentionFactor decreases from %.4g to %.4g.', ...
    dP(1), dP(end), retention(1), retention(end));
end

function evidence = core02Evidence(data)
[posOk, ~, posStart, posEnd] = absDecayCheck(data, 2e-6, 24e-6, +1);
[negOk, ~, negStart, negEnd] = absDecayCheck(data, 26e-6, 48e-6, -1);
evidence = sprintf('Positive retention decay ok=%d, |dP| %.4g -> %.4g. Negative retention decay ok=%d, |dP| %.4g -> %.4g.', ...
    posOk, posStart, posEnd, negOk, negStart, negEnd);
end

function [ok, maxRise, startAbs, endAbs] = absDecayCheck(data, t0, t1, expectedSign)
t = data.dP.time;
dP = data.dP.values;
idx = t >= t0 & t <= t1;
trace = dP(idx);
absTrace = abs(trace);
tol = 2e-3;
if isempty(trace)
    ok = false;
    maxRise = NaN;
    startAbs = NaN;
    endAbs = NaN;
    return;
end
maxRise = max([0; diff(absTrace)]);
startAbs = absTrace(1);
endAbs = absTrace(end);
signOk = all(expectedSign * trace > -tol);
decayOk = maxRise <= tol && endAbs <= startAbs + tol;
ok = signOk && decayOk;
end

function [ok, evidence] = returnedStateCheck(data, writeStart)
t = data.dP.time;
dt = median(diff(t));
preTime = writeStart - dt;
postTime = writeStart + dt;
preP17 = nearestAt(t, data.p17.values, preTime);
preP18 = nearestAt(t, data.p18.values, preTime);
postStart17 = nearestAt(t, data.pStart17.values, postTime);
postStart18 = nearestAt(t, data.pStart18.values, postTime);
err = max(abs([postStart17 - preP17, postStart18 - preP18]));
ok = err <= 0.02;
evidence = sprintf('handoff %.2f us error %.3g', writeStart * 1e6, err);
end

function value = nearestAt(t, y, target)
[~, idx] = min(abs(t - target));
value = y(idx);
end

function n = countStatus(results, status)
counted = ~strcmp(results.PaperSupport, 'NOT_IN_PAPERS');
n = sum(counted & strcmp(results.ModelStatus, status));
end

function writeReport(reportFile, results, coreResults)
fid = fopen(reportFile, 'w');
if fid < 0
    error('Unable to write report: %s', reportFile);
end
closer = onCleanup(@() fclose(fid));

fprintf(fid, '# FeFET Paper-Limited Testbench Results\n\n');
fprintf(fid, 'This report intentionally uses only the attached Preisach and NLS papers as the source of requirements. Requirements not present in those papers are marked `NOT_IN_PAPERS` and are not counted as pass/fail obligations.\n\n');
fprintf(fid, 'Sources:\n');
fprintf(fid, '- K. Ni, M. Jerry, J. A. Smith, and S. Datta, \"A Circuit Compatible Accurate Compact Model for Ferroelectric-FETs,\" 2018 IEEE Symposium on VLSI Technology, pp. 131-132, 2018.\n');
fprintf(fid, '- F. Mo et al., \"Efficient Erase Operation by GIDL Current for 3D Structure FeFETs With Gate Stack Engineering and Compact Long-Term Retention Model,\" IEEE Journal of the Electron Devices Society, vol. 10, pp. 115-122, 2022, doi: 10.1109/JEDS.2022.3142046.\n');
fprintf(fid, '- N. Gong, X. Sun, H. Jiang, K. S. Chang-Liao, Q. Xia, and T. P. Ma, \"Nucleation limited switching (NLS) model for HfO2-based metal-ferroelectric-metal (MFM) capacitors: Switching kinetics and retention characteristics,\" Applied Physics Letters, vol. 112, 262903, 2018, doi: 10.1063/1.5010207.\n\n');
fprintf(fid, '## Requested Nine-Item Audit\n\n');
fprintf(fid, '| Item | Requirement | Paper support | Model status | Evidence | Paper basis |\n');
fprintf(fid, '|---|---|---|---|---|---|\n');
for idx = 1:height(results)
    fprintf(fid, '| %s | %s | %s | %s | %s | %s |\n', ...
        results.ItemId{idx}, escapePipes(results.Requirement{idx}), ...
        results.PaperSupport{idx}, results.ModelStatus{idx}, ...
        escapePipes(results.Evidence{idx}), escapePipes(results.PaperBasis{idx}));
end

fprintf(fid, '\n## Core Paper-Derived Behavior\n\n');
fprintf(fid, '| Item | Requirement | Paper support | Model status | Evidence | Paper basis |\n');
fprintf(fid, '|---|---|---|---|---|---|\n');
for idx = 1:height(coreResults)
    fprintf(fid, '| %s | %s | %s | %s | %s | %s |\n', ...
        coreResults.ItemId{idx}, escapePipes(coreResults.Requirement{idx}), ...
        coreResults.PaperSupport{idx}, coreResults.ModelStatus{idx}, ...
        escapePipes(coreResults.Evidence{idx}), escapePipes(coreResults.PaperBasis{idx}));
end

fprintf(fid, '\n## Counts\n\n');
fprintf(fid, '- Requested paper-supported items: PASS=%d, PARTIAL=%d, FAIL=%d, NOT_IN_PAPERS=%d\n', ...
    countStatus(results, 'PASS'), countStatus(results, 'PARTIAL'), ...
    countStatus(results, 'FAIL'), sum(strcmp(results.PaperSupport, 'NOT_IN_PAPERS')));
fprintf(fid, '- Core paper-derived behavior checks: PASS=%d, PARTIAL=%d, FAIL=%d\n', ...
    sum(strcmp(coreResults.ModelStatus, 'PASS')), ...
    sum(strcmp(coreResults.ModelStatus, 'PARTIAL')), ...
    sum(strcmp(coreResults.ModelStatus, 'FAIL')));
end

function out = escapePipes(in)
out = strrep(in, '|', '\|');
end
