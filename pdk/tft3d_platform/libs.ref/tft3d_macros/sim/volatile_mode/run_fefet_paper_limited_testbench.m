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
preisachSweep = fetft_preisach_reference_sweep();

recurrent = collectSignals(recurrentOut, fetft_recurrent_hybrid_signal_names());
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
    'PARTIAL_IN_PAPERS', i02Status(recurrent), ...
    i02Evidence(recurrent), ...
    'Mo and Gong support NLS retention over short intervals with voltage/depolarization-field-dependent characteristic switching times. The exact r_i_plus/r_i_minus ODE notation is an implementation interface.');
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
    'PARTIAL_IN_PAPERS', i09Status(sequence, preisachSweep), ...
    i09Evidence(sequence, preisachSweep), ...
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
save(matFile, 'results', 'coreResults', 'recurrentOut', 'sequenceOut', 'preisachSweep');

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
hasDomains = all(hasNumberedFields(data, 'f17_', 8)) && all(hasNumberedFields(data, 'f18_', 8));
if ~hasDomains
    status = 'FAIL';
    return;
end

fOk = numberedValuesInRange(data, 'f17_', 8, -1e-9, 1.0 + 1e-9) && ...
    numberedValuesInRange(data, 'f18_', 8, -1e-9, 1.0 + 1e-9);
reconOk = reconstructionError(data, 'f17_', 'p17') < 1e-9 && ...
    reconstructionError(data, 'f18_', 'p18') < 1e-9;
if fOk && reconOk
    status = 'PASS';
else
    status = 'FAIL';
end
end

function evidence = i01Evidence(data)
err17 = reconstructionError(data, 'f17_', 'p17');
err18 = reconstructionError(data, 'f18_', 'p18');
minF = min([numberedMin(data, 'f17_', 8), numberedMin(data, 'f18_', 8)]);
maxF = max([numberedMax(data, 'f17_', 8), numberedMax(data, 'f18_', 8)]);
evidence = sprintf('Eight f_i bins per FeTFT branch are logged; f range %.4g..%.4g, reconstruction errors P17=%.3g and P18=%.3g.', ...
    minF, maxF, err17, err18);
end

function status = i02Status(data)
hasRates = all(hasNumberedFields(data, 'rPlus17_', 8)) && ...
    all(hasNumberedFields(data, 'rMinus17_', 8)) && ...
    all(hasNumberedFields(data, 'rPlus18_', 8)) && ...
    all(hasNumberedFields(data, 'rMinus18_', 8));
if ~hasRates
    status = 'FAIL';
    return;
end

phase = data.phase.values;
writeMask = phase == 1;
holdMask = phase == 2 | phase == 3;
writeRatesZero = numberedMax(data, 'rPlus17_', 8, writeMask) == 0.0 && ...
    numberedMax(data, 'rMinus17_', 8, writeMask) == 0.0 && ...
    numberedMax(data, 'rPlus18_', 8, writeMask) == 0.0 && ...
    numberedMax(data, 'rMinus18_', 8, writeMask) == 0.0;
holdRatesActive = numberedMax(data, 'rPlus17_', 8, holdMask) > 0.0 || ...
    numberedMax(data, 'rMinus17_', 8, holdMask) > 0.0 || ...
    numberedMax(data, 'rPlus18_', 8, holdMask) > 0.0 || ...
    numberedMax(data, 'rMinus18_', 8, holdMask) > 0.0;
finiteRates = numberedValuesInRange(data, 'rPlus17_', 8, 0.0, Inf) && ...
    numberedValuesInRange(data, 'rMinus17_', 8, 0.0, Inf) && ...
    numberedValuesInRange(data, 'rPlus18_', 8, 0.0, Inf) && ...
    numberedValuesInRange(data, 'rMinus18_', 8, 0.0, Inf);

if writeRatesZero && holdRatesActive && finiteRates
    status = 'PASS';
else
    status = 'FAIL';
end
end

function evidence = i02Evidence(data)
phase = data.phase.values;
holdMask = phase == 2 | phase == 3;
maxRate = max([numberedMax(data, 'rPlus17_', 8, holdMask), ...
    numberedMax(data, 'rMinus17_', 8, holdMask), ...
    numberedMax(data, 'rPlus18_', 8, holdMask), ...
    numberedMax(data, 'rMinus18_', 8, holdMask)]);
writeMaxRate = max([numberedMax(data, 'rPlus17_', 8, phase == 1), ...
    numberedMax(data, 'rMinus17_', 8, phase == 1), ...
    numberedMax(data, 'rPlus18_', 8, phase == 1), ...
    numberedMax(data, 'rMinus18_', 8, phase == 1)]);
evidence = sprintf('Per-domain equivalent NLS rates are logged; max hold/read rate %.4g s^-1 and max write rate %.4g s^-1.', ...
    maxRate, writeMaxRate);
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
hasFieldControl = isfield(data, 'vFe17') && isfield(data, 'vFe18') && ...
    isfield(data, 'eDep17') && isfield(data, 'eDep18') && ...
    isfield(data, 'eHold17') && isfield(data, 'eHold18') && ...
    isfield(data, 'eImp17') && isfield(data, 'eImp18');
signOk = mean(data.eDep17.values(phase == 2) .* data.p17.values(phase == 2) <= 1e-9) > 0.95 && ...
    mean(data.eDep18.values(phase == 2) .* data.p18.values(phase == 2) <= 1e-9) > 0.95;
if hasHold && retentionChanges && hasFieldControl && signOk
    status = 'PASS';
else
    status = 'FAIL';
end
end

function evidence = i05Evidence(data)
phase = data.phase.values;
minRetention = min(data.retentionFactor.values(phase == 2));
maxVfe = max(max(abs(data.vFe17.values(phase == 2))), max(abs(data.vFe18.values(phase == 2))));
evidence = sprintf('HOLD retention changes over time (min factor %.4g) while V_FE/E_dep/E_hold/E_imp terms are logged; max |V_FE| in hold is %.4g.', ...
    minRetention, maxVfe);
end

function status = i06Status(data)
[ok24, ~] = returnedStateCheck(data, 24e-6);
[ok48, ~] = returnedStateCheck(data, 48e-6);
hasHistory = isfield(data, 'history17Branch') && isfield(data, 'history18Branch') && ...
    isfield(data, 'history17TurnV') && isfield(data, 'history18TurnV') && ...
    isfield(data, 'history17TurnP') && isfield(data, 'history18TurnP') && ...
    isfield(data, 'history17Depth') && isfield(data, 'history18Depth');
hasBranches = any(abs(data.history17Branch.values) > 0) && any(abs(data.history18Branch.values) > 0);
if ok24 && ok48 && hasHistory && hasBranches
    status = 'PASS';
else
    status = 'FAIL';
end
end

function evidence = i06Evidence(data)
[~, e24] = returnedStateCheck(data, 24e-6);
[~, e48] = returnedStateCheck(data, 48e-6);
maxDepth = max(max(data.history17Depth.values), max(data.history18Depth.values));
evidence = sprintf('Serializable branch/turning-point/depth history fields are logged; max history depth %.4g. %s %s', ...
    maxDepth, e24, e48);
end

function status = i09Status(data, sweep)
finite = all(isfinite(data.vEff17.values)) && all(isfinite(data.dP.values));
hasPulseEffect = max(abs(data.vEff17.values)) > 0.1 && max(abs(data.dP.values)) > 0.1;
if finite && hasPulseEffect && sweep.pass
    status = 'PASS';
else
    status = 'FAIL';
end
end

function evidence = i09Evidence(data, sweep)
maxVeff = max(max(abs(data.vEff17.values)), max(abs(data.vEff18.values)));
maxDP = max(abs(data.dP.values));
evidence = sprintf('Simulink sequence is finite (max |Veff| %.4g V, max |dP| %.4g). Standalone Preisach sweep: %d cases, %d amplitudes, %d widths, %d starts, max error %.3g, unsaturated=%d.', ...
    maxVeff, maxDP, sweep.nCases, sweep.nAmplitudes, sweep.nWidths, ...
    sweep.nStartStates, sweep.maxAbsError, sweep.hasUnsaturated);
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

function present = hasNumberedFields(data, prefix, n)
present = false(1, n);
for idx = 1:n
    present(idx) = isfield(data, sprintf('%s%d', prefix, idx));
end
end

function ok = numberedValuesInRange(data, prefix, n, lower, upper)
ok = true;
for idx = 1:n
    values = data.(sprintf('%s%d', prefix, idx)).values;
    ok = ok && all(isfinite(values)) && all(values >= lower) && all(values <= upper);
end
end

function value = numberedMin(data, prefix, n, mask)
if nargin < 4
    mask = [];
end
value = Inf;
for idx = 1:n
    values = data.(sprintf('%s%d', prefix, idx)).values;
    if ~isempty(mask)
        values = values(mask);
    end
    value = min(value, min(values));
end
end

function value = numberedMax(data, prefix, n, mask)
if nargin < 4
    mask = [];
end
value = -Inf;
for idx = 1:n
    values = data.(sprintf('%s%d', prefix, idx)).values;
    if ~isempty(mask)
        values = values(mask);
    end
    value = max(value, max(values));
end
end

function err = reconstructionError(data, prefix, pName)
p = zeros(size(data.(pName).values));
for idx = 1:8
    f = data.(sprintf('%s%d', prefix, idx)).values;
    p = p + (2.0 .* f - 1.0) / 8.0;
end
err = max(abs(p - data.(pName).values));
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
