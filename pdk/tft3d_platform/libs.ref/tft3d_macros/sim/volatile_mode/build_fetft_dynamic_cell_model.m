function simOut = build_fetft_dynamic_cell_model(runSimulation)
%BUILD_FETFT_DYNAMIC_CELL_MODEL Create and optionally run a simple FeTFT dynamic-cell Simulink model.
%
% The model implements the reference-document DRAM/gain-cell abstraction:
%   WRITE creates a temporary differential polarization dP0.
%   HOLD lets dP decay with an effective NLS depolarization/back-switching law.
%   READ raises the polarization-to-voltage gain while keeping loop gain < 1.
%
% NLS/detrapping retention mechanism adapted from:
% F. Mo et al., "Efficient Erase Operation by GIDL Current for 3D Structure
% FeFETs With Gate Stack Engineering and Compact Long-Term Retention Model,"
% IEEE Journal of the Electron Devices Society, vol. 10, pp. 115-122, 2022,
% doi: 10.1109/JEDS.2022.3142046.
%
% Usage:
%   build_fetft_dynamic_cell_model
%   build_fetft_dynamic_cell_model(false)

if nargin < 1
    runSimulation = true;
end

if isempty(ver('simulink'))
    error('Simulink is not available in this MATLAB installation.');
end

thisDir = fileparts(mfilename('fullpath'));
modelName = 'fetft_dram_like_dynamic_cell';
modelFile = fullfile(thisDir, [modelName '.slx']);
resultsFile = fullfile(thisDir, 'fetft_dynamic_cell_results.mat');
plotFile = fullfile(thisDir, 'fetft_dynamic_cell_response.png');

params = defaultParameters();

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

new_system(modelName);
set_param(modelName, ...
    'StopTime', num2str(params.tStop), ...
    'Solver', 'ode45', ...
    'MaxStep', num2str(params.maxStep), ...
    'SaveOutput', 'on', ...
    'ReturnWorkspaceOutputs', 'on', ...
    'SignalLogging', 'off');

createBlocks(modelName, params);
save_system(modelName, modelFile);

fprintf('Created Simulink model: %s\n', modelFile);
fprintf('Default retention estimate tR = %.3g s\n', retentionEstimate(params));

if runSimulation
    simOut = sim(modelName);
    save(resultsFile, 'simOut', 'params');
    makePlot(simOut, plotFile);
    fprintf('Simulation complete: %s\n', resultsFile);
    fprintf('Response plot: %s\n', plotFile);
else
    simOut = [];
end

end

function params = defaultParameters()
% Reference-derived circuit-level demonstration parameters.
% The NLS and detrapping parameters below are illustrative placeholders for
% the time-dependent state-decay mechanism, not calibrated FeFET model values.
params.tWrite = 2e-6;          % s, write pulse duration
params.tReadStart = 22e-6;     % s, read starts after hold interval
params.tStop = 40e-6;          % s, total transient duration
params.maxStep = 5e-8;         % s

params.dP0 = 1.0;              % normalized target differential polarization
params.tauWrite = 0.35e-6;     % s, partial polarization programming time
params.tauNls = 11e-6;         % s, effective field-dependent NLS time scale
params.betaRetention = 0.62;   % stretched-exponential NLS shape factor
params.trapAccel = 0.18;       % optional charge-detrapping acceleration factor
params.tauTrap = 25e-6;        % s, detrapping transient time scale
params.pEq = 0.0;              % normalized common equilibrium polarization

params.aWrite = 0.25;          % effective regenerative factor during write
params.aHold = 0.35;           % hold must stay below unity
params.aRead = 0.88;           % read approaches unity from below
params.bWrite = 0.12;          % V per normalized dP
params.bHold = 0.08;           % V per normalized dP
params.bRead = 0.12;           % V per normalized dP

params.vMin = 0.12;            % V, minimum readable differential margin
params.kappa = 0.35;           % V per normalized dP, threshold-difference proxy
params.gmProxy = 1.0;          % normalized transconductance proxy
params.gPProxy = 0.20;         % normalized polarization-current proxy
end

function createBlocks(modelName, params)
block = @(name) [modelName '/' name];

add_block('simulink/Sources/Clock', block('time'), ...
    'Position', [55 95 85 125]);

equationBlock = block('FeTFT dynamic cell equations');
add_block(sprintf('simulink/User-Defined\nFunctions/Interpreted MATLAB\nFunction'), equationBlock, ...
    'MATLABFcn', 'fetft_cell_vector', ...
    'OutputDimensions', '11', ...
    'Position', [145 35 375 315]);

add_block('simulink/Signal Routing/Demux', block('output demux'), ...
    'Outputs', '11', ...
    'Position', [425 45 430 485]);

signals = { ...
    'phase', 'dP', 'p17', 'p18', 'dVQ', 'loopGain', ...
    'polarizationGain', 'senseMargin', 'vtShift', 'idProxy', 'refreshNeeded'};

for idx = 1:numel(signals)
    y = 25 + 42 * idx;
    outBlock = block(['to_' signals{idx}]);
    add_block('simulink/Sinks/To Workspace', outBlock, ...
        'VariableName', signals{idx}, ...
        'SaveFormat', 'Structure With Time', ...
        'Position', [500 y 625 y + 26]);
    add_line(modelName, sprintf('output demux/%d', idx), ...
        ['to_' signals{idx} '/1'], 'autorouting', 'on');
end

add_block('simulink/Signal Routing/Mux', block('response mux'), ...
    'Inputs', '4', ...
    'Position', [505 545 510 650]);
add_block('simulink/Sinks/Scope', block('core response scope'), ...
    'Position', [580 555 730 645]);

add_line(modelName, 'time/1', 'FeTFT dynamic cell equations/1', 'autorouting', 'on');
add_line(modelName, 'FeTFT dynamic cell equations/1', 'output demux/1', 'autorouting', 'on');
add_line(modelName, 'output demux/2', 'response mux/1', 'autorouting', 'on');
add_line(modelName, 'output demux/5', 'response mux/2', 'autorouting', 'on');
add_line(modelName, 'output demux/8', 'response mux/3', 'autorouting', 'on');
add_line(modelName, 'output demux/11', 'response mux/4', 'autorouting', 'on');
add_line(modelName, 'response mux/1', 'core response scope/1', 'autorouting', 'on');

annotationText = sprintf([ ...
    'FeTFT DRAM-like dynamic cell abstraction\\n', ...
    'WRITE: create dP0. HOLD: NLS depolarization/back-switching and loop gain < 1.\\n', ...
    'READ: gain = B/(1-a), with a close to unity from below.']);
annotation = Simulink.Annotation(modelName, annotationText);
annotation.Position = [40 345 440 415];

set_param(modelName, 'ZoomFactor', 'FitSystem');
end

function tR = retentionEstimate(params)
dPWriteEnd = params.dP0 * (1.0 - exp(-params.tWrite / params.tauWrite));
gRead = params.bRead / (1.0 - params.aRead);
if gRead * abs(dPWriteEnd) <= params.vMin
    tR = 0.0;
else
    lo = 0.0;
    hi = max(params.tauNls, params.tStop - params.tWrite);
    while retentionMarginAt(hi, dPWriteEnd, gRead, params) > 0.0
        hi = 2.0 * hi;
    end
    for idx = 1:80
        mid = 0.5 * (lo + hi);
        if retentionMarginAt(mid, dPWriteEnd, gRead, params) > 0.0
            lo = mid;
        else
            hi = mid;
        end
    end
    tR = 0.5 * (lo + hi);
end
end

function margin = retentionMarginAt(tHold, dPWriteEnd, gRead, params)
trapMultiplier = 1.0 + params.trapAccel * (1.0 - exp(-tHold / params.tauTrap));
remaining = exp(-trapMultiplier * (tHold / params.tauNls) .^ params.betaRetention);
margin = gRead * abs(dPWriteEnd) * remaining - params.vMin;
end

function makePlot(simOut, plotFile)
time = simOut.get('dP').time;
dP = simOut.get('dP').signals.values;
dVQ = simOut.get('dVQ').signals.values;
margin = simOut.get('senseMargin').signals.values;
phase = simOut.get('phase').signals.values;

fig = figure('Visible', 'off', 'Color', 'w');
tiledlayout(fig, 3, 1, 'TileSpacing', 'compact');

nexttile;
plot(time * 1e6, dP, 'LineWidth', 1.5);
grid on;
ylabel('\DeltaP norm.');
title('FeTFT dynamic-cell response');

nexttile;
plot(time * 1e6, dVQ, 'LineWidth', 1.5);
grid on;
ylabel('\DeltaV_Q (V)');

nexttile;
plot(time * 1e6, margin, 'LineWidth', 1.5);
hold on;
stairs(time * 1e6, 0.05 * phase, ':', 'LineWidth', 1.0);
grid on;
xlabel('time (\mus)');
ylabel('margin (V)');
legend('sense margin', 'phase marker', 'Location', 'best');

exportgraphics(fig, plotFile, 'Resolution', 160);
close(fig);
end
