function simOut = build_fetft_recurrent_hybrid_model(runSimulation, cfg)
%BUILD_FETFT_RECURRENT_HYBRID_MODEL Create a recurrent Preisach-retention model.
%
% This model implements the stronger hybrid interaction:
%   Preisach writes the state -> NLS retention relaxes it -> the next
%   Preisach write starts from the relaxed state.
%
% No NLS switching is applied during WRITE. WRITE uses only the reduced
% Preisach programming law with RC-delayed effective FE voltage. NLS and
% detrapping are applied only outside the write pulse.
%
% Preisach programming abstraction adapted from:
% K. Ni, M. Jerry, J. A. Smith, and S. Datta, "A Circuit Compatible Accurate
% Compact Model for Ferroelectric-FETs," 2018 IEEE Symposium on VLSI
% Technology, pp. 131-132, 2018.
%
% NLS/detrapping retention mechanism adapted from:
% F. Mo et al., "Efficient Erase Operation by GIDL Current for 3D Structure
% FeFETs With Gate Stack Engineering and Compact Long-Term Retention Model,"
% IEEE Journal of the Electron Devices Society, vol. 10, pp. 115-122, 2022,
% doi: 10.1109/JEDS.2022.3142046.
%
% NLS domain-population/rate abstraction adapted from:
% N. Gong et al., "Nucleation limited switching (NLS) model for HfO2-based
% metal-ferroelectric-metal (MFM) capacitors: Switching kinetics and
% retention characteristics," Applied Physics Letters, vol. 112, 262903,
% 2018, doi: 10.1063/1.5010207.

if nargin < 1
    runSimulation = true;
end

if nargin < 2 || isempty(cfg)
    cfg = struct();
end

if isempty(ver('simulink'))
    error('Simulink is not available in this MATLAB installation.');
end

thisDir = fileparts(mfilename('fullpath'));
modelName = 'fetft_recurrent_hybrid_write_hold_read';
modelFile = fullfile(thisDir, [modelName '.slx']);
resultsFile = fullfile(thisDir, 'fetft_recurrent_hybrid_results.mat');
plotFile = fullfile(thisDir, 'fetft_recurrent_hybrid_response.png');

params = defaultParameters(cfg);
recurrentHybridInput = fetft_recurrent_hybrid_dataset(params.tStop, params.dt, cfg);
assignin('base', 'recurrentHybridInput', recurrentHybridInput);
assignin('base', 'fetftRecurrentHybridCfg', cfg);

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

new_system(modelName);
initFcn = sprintf(['if ~exist(''fetftRecurrentHybridCfg'', ''var''), ', ...
    'fetftRecurrentHybridCfg = struct(); end; ', ...
    'recurrentHybridInput = fetft_recurrent_hybrid_dataset(%0.17g, %0.17g, fetftRecurrentHybridCfg);'], ...
    params.tStop, params.dt);
set_param(modelName, ...
    'StopTime', num2str(params.tStop), ...
    'Solver', 'FixedStepDiscrete', ...
    'FixedStep', num2str(params.dt), ...
    'SaveOutput', 'on', ...
    'ReturnWorkspaceOutputs', 'on', ...
    'SignalLogging', 'off', ...
    'InitFcn', initFcn);

createBlocks(modelName);
save_system(modelName, modelFile);

fprintf('Created recurrent hybrid model: %s\n', modelFile);

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

function params = defaultParameters(cfg)
params.tStop = 80e-6;
params.dt = 5e-8;
if isfield(cfg, 'tStop')
    params.tStop = cfg.tStop;
end
if isfield(cfg, 'dt')
    params.dt = cfg.dt;
end
end

function createBlocks(modelName)
block = @(name) [modelName '/' name];

add_block('simulink/Sources/From Workspace', block('Recurrent hybrid input'), ...
    'VariableName', 'recurrentHybridInput', ...
    'Interpolate', 'off', ...
    'OutputAfterFinalValue', 'Holding final value', ...
    'Position', [80 265 255 310]);

signals = fetft_recurrent_hybrid_signal_names();
add_block('simulink/Signal Routing/Demux', block('output demux'), ...
    'Outputs', num2str(numel(signals)), ...
    'Position', [335 35 340 50 + 30 * numel(signals)]);

for idx = 1:numel(signals)
    y = 15 + 30 * idx;
    outBlock = block(['to_' signals{idx}]);
    add_block('simulink/Sinks/To Workspace', outBlock, ...
        'VariableName', signals{idx}, ...
        'SaveFormat', 'Structure With Time', ...
        'Position', [430 y 585 y + 20]);
    add_line(modelName, sprintf('output demux/%d', idx), ...
        ['to_' signals{idx} '/1'], 'autorouting', 'on');
end

add_block('simulink/Signal Routing/Mux', block('scope mux'), ...
    'Inputs', '7', ...
    'Position', [650 90 655 285]);
add_block('simulink/Sinks/Scope', block('Recurrent interaction scope'), ...
    'Position', [730 125 930 255]);

add_line(modelName, 'Recurrent hybrid input/1', 'output demux/1', 'autorouting', 'on');
add_line(modelName, 'output demux/2', 'scope mux/1', 'autorouting', 'on');
add_line(modelName, 'output demux/11', 'scope mux/2', 'autorouting', 'on');
add_line(modelName, 'output demux/12', 'scope mux/3', 'autorouting', 'on');
add_line(modelName, 'output demux/13', 'scope mux/4', 'autorouting', 'on');
add_line(modelName, 'output demux/14', 'scope mux/5', 'autorouting', 'on');
add_line(modelName, 'output demux/15', 'scope mux/6', 'autorouting', 'on');
add_line(modelName, 'output demux/18', 'scope mux/7', 'autorouting', 'on');
add_line(modelName, 'scope mux/1', 'Recurrent interaction scope/1', 'autorouting', 'on');

annotationText = sprintf([ ...
    'Recurrent hybrid model for volatile FeTFT bitcell\n', ...
    'WRITE: Preisach programming from the current relaxed P state. No NLS switching during write.\n', ...
    'HOLD/READ: Gong/Mo-style NLS domain populations and rates relax P; the relaxed P is fed into the next write.']);
annotation = Simulink.Annotation(modelName, annotationText);
annotation.Position = [40 420 835 500];

set_param(modelName, 'ZoomFactor', 'FitSystem');
end

function makePlot(simOut, plotFile)
time = simOut.get('dP').time;
writeCommand = simOut.get('writeCommand').signals.values;
p17 = simOut.get('p17').signals.values;
p18 = simOut.get('p18').signals.values;
dPProgrammed = simOut.get('dPProgrammed').signals.values;
retentionFactor = simOut.get('retentionFactor').signals.values;
dP = simOut.get('dP').signals.values;
dVQ = simOut.get('dVQ').signals.values;
margin = simOut.get('senseMargin').signals.values;

fig = figure('Visible', 'off', 'Color', 'w');
tiledlayout(fig, 5, 1, 'TileSpacing', 'compact');

nexttile;
stairs(time * 1e6, writeCommand, 'LineWidth', 1.3);
grid on;
ylabel('write cmd');
title('Recurrent Preisach write + NLS retention interaction');

nexttile;
plot(time * 1e6, p17, 'LineWidth', 1.4);
hold on;
plot(time * 1e6, p18, 'LineWidth', 1.4);
grid on;
ylabel('P state');
legend('P17', 'P18', 'Location', 'best');

nexttile;
plot(time * 1e6, dPProgrammed, '--', 'LineWidth', 1.2);
hold on;
plot(time * 1e6, dP, 'LineWidth', 1.5);
grid on;
ylabel('DeltaP');
legend('programmed/start', 'after retention', 'Location', 'best');

nexttile;
plot(time * 1e6, retentionFactor, 'LineWidth', 1.5);
grid on;
ylabel('retention');

nexttile;
plot(time * 1e6, dVQ, 'LineWidth', 1.4);
hold on;
plot(time * 1e6, margin, 'LineWidth', 1.4);
grid on;
xlabel('time (us)');
ylabel('V');
legend('DeltaV_Q', 'margin', 'Location', 'best');

exportgraphics(fig, plotFile, 'Resolution', 160);
close(fig);
end
