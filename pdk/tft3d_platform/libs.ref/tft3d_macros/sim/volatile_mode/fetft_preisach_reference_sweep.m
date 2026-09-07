function sweep = fetft_preisach_reference_sweep()
%FETFT_PREISACH_REFERENCE_SWEEP Reduced Ni-style Preisach reference sweep.
%
% Ni et al. emphasize that FeFET response depends on write amplitude, pulse
% width, and history/minor-loop trajectory. This helper checks the reduced
% programming law used by the Simulink sequence over those axes.

params = default_params();
amplitudes = [0.5, 0.75, 1.0] * params.vWrite;
widths = [0.1, 1.0, 10.0] * params.tp;
starts = [-0.4, 0.0, 0.4];
polarities = [-1.0, 1.0];

rows = {};
caseIdx = 1;
for startIdx = 1:numel(starts)
    for ampIdx = 1:numel(amplitudes)
        for widthIdx = 1:numel(widths)
            for polIdx = 1:numel(polarities)
                startP = starts(startIdx);
                amplitude = amplitudes(ampIdx);
                width = widths(widthIdx);
                polarity = polarities(polIdx);
                [modelEnd, historyState] = stepped_write(startP, polarity * amplitude, width, params);
                referenceEnd = closed_form_write(startP, polarity * amplitude, width, params);
                err = abs(modelEnd - referenceEnd);
                unsaturated = abs(modelEnd) < 0.98 * params.minorScale;

                rows(end + 1, :) = {caseIdx, startP, amplitude, width, polarity, ...
                    modelEnd, referenceEnd, err, historyState.branch, ...
                    historyState.turnP, historyState.depth, unsaturated}; %#ok<AGROW>
                caseIdx = caseIdx + 1;
            end
        end
    end
end

cases = cell2table(rows, 'VariableNames', { ...
    'CaseId', 'StartP', 'Amplitude', 'Width', 'Polarity', ...
    'ModelEndP', 'ReferenceEndP', 'AbsError', 'HistoryBranch', ...
    'HistoryTurnP', 'HistoryDepth', 'Unsaturated'});

sweep = struct();
sweep.cases = cases;
sweep.maxAbsError = max(cases.AbsError);
sweep.nCases = height(cases);
sweep.nAmplitudes = numel(unique(cases.Amplitude));
sweep.nWidths = numel(unique(cases.Width));
sweep.nStartStates = numel(unique(cases.StartP));
sweep.hasBothPolarities = all(ismember([-1.0, 1.0], unique(cases.Polarity)));
sweep.hasUnsaturated = any(cases.Unsaturated);
sweep.pass = sweep.maxAbsError <= 1e-12 && sweep.nAmplitudes >= 3 && ...
    sweep.nWidths >= 3 && sweep.nStartStates >= 3 && ...
    sweep.hasBothPolarities && sweep.hasUnsaturated;
end

function params = default_params()
params.vWrite = 2.4;
params.tp = 2e-6;
params.tauVeff = 0.28e-6;
params.pSat = 1.0;
params.alphaPreisach = 1.55;
params.vCoercive = 0.85;
params.minorScale = 0.78;
end

function [p, history] = stepped_write(pStart, vPulse, width, params)
nSteps = 200;
times = linspace(0.0, width, nSteps);
p = pStart;
history = initial_history();
for idx = 1:numel(times)
    vEff = delayed_voltage(vPulse, times(idx), params.tauVeff);
    pTarget = preisach_target(vEff, params);
    p = minor_loop_update(pStart, pTarget, params);
    history = update_history(history, sign_nonzero(vPulse), vEff, pStart, p);
end
end

function p = closed_form_write(pStart, vPulse, width, params)
vEff = delayed_voltage(vPulse, width, params.tauVeff);
pTarget = preisach_target(vEff, params);
p = minor_loop_update(pStart, pTarget, params);
end

function history = initial_history()
history.branch = 0.0;
history.turnV = 0.0;
history.turnP = 0.0;
history.depth = 0.0;
end

function history = update_history(history, branch, vEff, pTurn, pNow)
if history.branch ~= branch && branch ~= 0.0
    history.turnV = 0.0;
    history.turnP = pTurn;
end
history.branch = branch;
history.depth = abs(pNow - history.turnP);
if branch == 0.0
    history.turnV = vEff;
end
end

function value = delayed_voltage(vIn, tLocal, tauVeff)
if tLocal <= 0
    value = 0.0;
else
    value = vIn * (1.0 - exp(-tLocal / tauVeff));
end
end

function p = preisach_target(vEff, params)
if vEff >= 0
    pRaw = params.pSat * tanh(params.alphaPreisach * (vEff - params.vCoercive));
    p0 = params.pSat * tanh(params.alphaPreisach * (0.0 - params.vCoercive));
    p = params.minorScale * (pRaw - p0) / (params.pSat - p0);
else
    pRaw = params.pSat * tanh(params.alphaPreisach * (vEff + params.vCoercive));
    p0 = params.pSat * tanh(params.alphaPreisach * (0.0 + params.vCoercive));
    p = params.minorScale * (pRaw - p0) / (params.pSat + p0);
end
end

function p = minor_loop_update(pStart, pTarget, params)
drive = min(abs(pTarget) / params.minorScale, 1.0);
p = pStart + drive * (pTarget - pStart);
end

function value = sign_nonzero(value)
if value > 0.0
    value = 1.0;
elseif value < 0.0
    value = -1.0;
else
    value = 0.0;
end
end
