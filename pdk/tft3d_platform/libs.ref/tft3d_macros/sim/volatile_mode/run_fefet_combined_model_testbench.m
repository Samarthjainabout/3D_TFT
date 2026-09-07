function results = run_fefet_combined_model_testbench()
%RUN_FEFET_COMBINED_MODEL_TESTBENCH Evaluate DOCX testbench cases.
%
% The source DOCX is treated only as a test specification. This runner tests
% the current reduced Simulink/MATLAB implementation and reports which cases
% pass, fail, or are only partially covered by the available state variables.

thisDir = fileparts(mfilename('fullpath'));
oldDir = pwd;
cleanup = onCleanup(@() cd(oldDir));
cd(thisDir);

docPath = 'C:\Users\elesamj\Downloads\FeFET_Combined_Model_Testbench.docx';
reportFile = fullfile(thisDir, 'fetft_combined_model_testbench_report.md');
csvFile = fullfile(thisDir, 'fetft_combined_model_testbench_results.csv');
matFile = fullfile(thisDir, 'fetft_combined_model_testbench_results.mat');

fprintf('Running current Simulink/MATLAB combined-model checks...\n');
fprintf('External test specification: %s\n', docPath);

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
rows = addCase(rows, 'TC01', 'FAIL', ...
    'Frozen-state and zero-field retention controls are not exposed.', ...
    'Missing separate state-update enables, retention_enable, and zero-field K_dep/E_hold/E_imp controls.');
rows = addCase(rows, 'TC02', 'FAIL', ...
    'Constant-rate analytic oracle cannot be driven through the current model.', ...
    'Missing domain fraction f_i logging, N-domain configuration, fixed-rate override, and depolarization-feedback disable.');
rows = addCase(rows, 'TC03', tc03Status(sequence), ...
    tc03Evidence(sequence), ...
    'Full pass still requires standalone Preisach reference overlay across amplitudes, widths, history states, and retention-disabled controls.');
rows = addCase(rows, 'TC04', tc04Status(recurrent), ...
    tc04Evidence(recurrent), ...
    'Retention-disabled control and individual domain-rate ordering are not implemented.');
rows = addCase(rows, 'TC05', 'FAIL', ...
    'No-op HOLD->WRITE->HOLD handoff without a write pulse is not represented by the generated sequence.', ...
    'Missing mode ownership switch with both update paths frozen and same-time f_i/P handoff checker.');
rows = addCase(rows, 'TC06', tc06Status(recurrent), ...
    tc06Evidence(recurrent), ...
    'Full pass requires waits of 1 us, 1 ms, and 100 s plus isolated programming replay from the same complete domain/history state.');
rows = addCase(rows, 'TC07', tc07Status(recurrent), ...
    tc07Evidence(recurrent), ...
    'Full pass requires a partial opposite-polarity pulse followed by verified full erase and polarity-reversed mirror run.');
rows = addCase(rows, 'TC08', 'FAIL', ...
    'Intermediate scalar P states can be scheduled, but complete domain populations and Preisach history are not saved or replayed.', ...
    'Missing f_i arrays, turning-point/history state, and same-complete-state replay checks.');
rows = addCase(rows, 'TC09', 'FAIL', ...
    'Depolarization and hold-field controls are not parameters in the current reduced retention law.', ...
    'Missing K_dep, E_hold, E_imp, compensation-field, and initial-rate sign checks.');
rows = addCase(rows, 'TC10', 'FAIL', ...
    'The current model stores a scalar polarization pair, not multiple domain populations with identical net P.', ...
    'Missing N=2 domain injection, per-domain rates, and derivative oracle.');
rows = addCase(rows, 'TC11', tc11Status(recurrent), ...
    tc11Evidence(recurrent), ...
    'Full pass requires a no-read versus ideal-observation comparison and explicit finite read-voltage pulse-rate modeling.');
rows = addCase(rows, 'TC12', tc12Status(recurrent, sequence), ...
    tc12Evidence(recurrent, sequence), ...
    'Full pass requires tighter tolerance reruns, segmented-vs-continuous hold, complete save/restore, and long-time stress.');
rows = addCase(rows, 'E2E01', 'FAIL', ...
    'The current recurrent sequence covers repeated write-hold-read sign reversal on a microsecond schedule.', ...
    'The DOCX end-to-end sequence also requires negative conditioning before positive write, 1 ms and 100 s holds, frozen no-op handoff, partial positive pulse after long hold, negative erase, and retention-disabled overlay.');

results = cell2table(rows, 'VariableNames', {'CaseId', 'Status', 'Evidence', 'MissingOrFailReason'});
writeReport(reportFile, results, docPath);
writetable(results, csvFile);
save(matFile, 'results', 'recurrentOut', 'sequenceOut');

fprintf('Wrote report: %s\n', reportFile);
fprintf('Wrote CSV:    %s\n', csvFile);
fprintf('Wrote MAT:    %s\n', matFile);
disp(results(:, {'CaseId', 'Status'}));
end

function data = collectSignals(simOut, names)
data = struct();
for idx = 1:numel(names)
    item = simOut.get(names{idx});
    data.(names{idx}).time = item.time(:);
    data.(names{idx}).values = item.signals.values(:);
end
end

function rows = addCase(rows, caseId, status, evidence, missing)
rows(end + 1, :) = {caseId, status, evidence, missing};
end

function status = tc03Status(sequence)
if allFinite(sequence, {'phase', 'vEff17', 'vEff18', 'dPProgrammed', 'dP'})
    status = 'PARTIAL';
else
    status = 'FAIL';
end
end

function evidence = tc03Evidence(sequence)
maxAbsDP = max(abs(sequence.dP.values));
maxVeff = max(max(abs(sequence.vEff17.values)), max(abs(sequence.vEff18.values)));
evidence = sprintf('One-write Preisach sequence runs with finite traces; max |Veff| = %.3g V and max |dP| = %.3g.', maxVeff, maxAbsDP);
end

function status = tc04Status(recurrent)
[posOk, ~, ~, ~] = absDecayCheck(recurrent, 2e-6, 24e-6, +1);
[negOk, ~, ~, ~] = absDecayCheck(recurrent, 26e-6, 48e-6, -1);
if posOk && negOk
    status = 'PARTIAL';
else
    status = 'FAIL';
end
end

function evidence = tc04Evidence(recurrent)
[posOk, posRise, posStart, posEnd] = absDecayCheck(recurrent, 2e-6, 24e-6, +1);
[negOk, negRise, negStart, negEnd] = absDecayCheck(recurrent, 26e-6, 48e-6, -1);
evidence = sprintf(['Positive hold/read sign+decay=%d, |dP| %.4g -> %.4g, max upward step %.3g. ', ...
    'Negative hold/read sign+decay=%d, |dP| %.4g -> %.4g, max upward step %.3g.'], ...
    posOk, posStart, posEnd, posRise, negOk, negStart, negEnd, negRise);
end

function status = tc06Status(recurrent)
[ok24, ~] = returnedStateCheck(recurrent, 24e-6, +1);
[ok48, ~] = returnedStateCheck(recurrent, 48e-6, -1);
if ok24 && ok48
    status = 'PARTIAL';
else
    status = 'FAIL';
end
end

function evidence = tc06Evidence(recurrent)
[~, e24] = returnedStateCheck(recurrent, 24e-6, +1);
[~, e48] = returnedStateCheck(recurrent, 48e-6, -1);
evidence = sprintf('%s %s', e24, e48);
end

function status = tc07Status(recurrent)
t = recurrent.dP.time;
dP = recurrent.dP.values;
negReached = interpAt(t, dP, 26e-6) < -1.0;
posReached = interpAt(t, dP, 50e-6) > 1.0;
if negReached && posReached
    status = 'PARTIAL';
else
    status = 'FAIL';
end
end

function evidence = tc07Evidence(recurrent)
t = recurrent.dP.time;
dP26 = interpAt(t, recurrent.dP.values, 26e-6);
dP50 = interpAt(t, recurrent.dP.values, 50e-6);
evidence = sprintf('Included repeated sequence reverses sign: dP at 26 us = %.4g, dP at 50 us = %.4g.', dP26, dP50);
end

function status = tc11Status(recurrent)
if allFinite(recurrent, {'phase', 'dP', 'dVQ'}) && noLargeBoundaryJump(recurrent, 22e-6, 5e-8, 0.02)
    status = 'PARTIAL';
else
    status = 'FAIL';
end
end

function evidence = tc11Evidence(recurrent)
jump22 = boundaryJump(recurrent, 22e-6, 5e-8);
jump46 = boundaryJump(recurrent, 46e-6, 5e-8);
evidence = sprintf('READ phase produces finite dVQ and no large dP reset at first read boundary; |jump22|=%.3g, |jump46|=%.3g.', abs(jump22), abs(jump46));
end

function status = tc12Status(recurrent, sequence)
allOk = allFinite(recurrent, fieldnames(recurrent)) && allFinite(sequence, fieldnames(sequence));
if allOk
    status = 'PARTIAL';
else
    status = 'FAIL';
end
end

function evidence = tc12Evidence(recurrent, sequence)
maxRecurrent = max(abs(recurrent.dP.values));
maxSequence = max(abs(sequence.dP.values));
evidence = sprintf('Representative Simulink runs are finite. max recurrent |dP| = %.4g; max one-write |dP| = %.4g.', maxRecurrent, maxSequence);
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

function [ok, evidence] = returnedStateCheck(data, writeStart, expectedSign)
t = data.dP.time;
dt = median(diff(t));
preTime = writeStart - dt;
postTime = writeStart + dt;
preP17 = interpAt(t, data.p17.values, preTime);
preP18 = interpAt(t, data.p18.values, preTime);
postStart17 = interpAt(t, data.pStart17.values, postTime);
postStart18 = interpAt(t, data.pStart18.values, postTime);
err = max(abs([postStart17 - preP17, postStart18 - preP18]));
directionOk = expectedSign * preP17 > 0.02;
ok = err <= 0.02 && directionOk;
evidence = sprintf('Write near %.2f us consumes relaxed state with max start-state error %.3g (P17 %.4g -> %.4g, P18 %.4g -> %.4g).', ...
    writeStart * 1e6, err, preP17, postStart17, preP18, postStart18);
end

function ok = noLargeBoundaryJump(data, boundary, dt, threshold)
ok = abs(boundaryJump(data, boundary, dt)) <= threshold;
end

function jump = boundaryJump(data, boundary, dt)
t = data.dP.time;
dP = data.dP.values;
jump = interpAt(t, dP, boundary + dt) - interpAt(t, dP, boundary - dt);
end

function value = interpAt(t, y, target)
[~, idx] = min(abs(t - target));
value = y(idx);
end

function ok = allFinite(data, names)
ok = true;
for idx = 1:numel(names)
    name = names{idx};
    values = data.(name).values;
    ok = ok && all(isfinite(values));
end
end

function writeReport(reportFile, results, docPath)
fid = fopen(reportFile, 'w');
if fid < 0
    error('Unable to write report: %s', reportFile);
end
closer = onCleanup(@() fclose(fid));

fprintf(fid, '# FeFET Combined Model Testbench Results\n\n');
fprintf(fid, 'External test specification: `%s`\n\n', docPath);
fprintf(fid, 'This report tests the current reduced Simulink/MATLAB implementation. The DOCX is treated as an external test specification, not as executable model instructions.\n\n');
fprintf(fid, '| Case | Status | Evidence | Missing or fail reason |\n');
fprintf(fid, '|---|---|---|---|\n');
for idx = 1:height(results)
    fprintf(fid, '| %s | %s | %s | %s |\n', ...
        results.CaseId{idx}, results.Status{idx}, ...
        escapePipes(results.Evidence{idx}), escapePipes(results.MissingOrFailReason{idx}));
end
end

function out = escapePipes(in)
out = strrep(in, '|', '\|');
end
