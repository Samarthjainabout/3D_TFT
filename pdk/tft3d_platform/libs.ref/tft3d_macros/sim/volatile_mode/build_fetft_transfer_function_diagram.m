function simOut = build_fetft_transfer_function_diagram(runSimulation)
%BUILD_FETFT_TRANSFER_FUNCTION_DIAGRAM Create a Simulink transfer-function block diagram.
%
% The diagram implements the circuit-level FeTFT bitcell relations:
%   V_Qbar = G17(s) V_Q + B17(s) P17
%   V_Q    = G18(s) V_Qbar + B18(s) P18
%   DeltaV_Q = V_Q - V_Qbar
%
% G17 and G18 are the inverting cross-coupled branches from the reference
% document. A first-order Gamma_P(s) term is folded into each branch:
%   G_i(s) = -[gm_i + gP_i * kGamma_i/(tauGamma_i*s + 1)] / [C_i*s + G_i]
%
% The NLS/detrapping state-decay model is handled in
% build_fetft_dynamic_cell_model.m; this file is only the small-signal
% transfer-function block diagram.

if nargin < 1
    runSimulation = true;
end

if isempty(ver('simulink'))
    error('Simulink is not available in this MATLAB installation.');
end

thisDir = fileparts(mfilename('fullpath'));
modelName = 'fetft_transfer_function_block_diagram';
modelFile = fullfile(thisDir, [modelName '.slx']);
diagramFile = fullfile(thisDir, [modelName '.png']);
resultsFile = fullfile(thisDir, 'fetft_transfer_function_results.mat');

params = defaultTransferParameters();

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

new_system(modelName);
set_param(modelName, ...
    'StopTime', num2str(params.tStop), ...
    'Solver', 'ode45', ...
    'MaxStep', num2str(params.maxStep), ...
    'SaveOutput', 'on', ...
    'ReturnWorkspaceOutputs', 'on');

createTransferDiagram(modelName, params);
save_system(modelName, modelFile);
exportDiagram(modelName, diagramFile);

fprintf('Created Simulink transfer-function model: %s\n', modelFile);
fprintf('Exported block diagram image: %s\n', diagramFile);
fprintf('Low-frequency loop gain estimate: %.3f\n', dcLoopGain(params));

if runSimulation
    simOut = sim(modelName);
    save(resultsFile, 'simOut', 'params');
    fprintf('Simulation complete: %s\n', resultsFile);
else
    simOut = [];
end

end

function params = defaultTransferParameters()
params.tStop = 80e-6;
params.maxStep = 1e-7;

params.p17StepTime = 1e-6;
params.p18StepTime = 1e-6;
params.p17Final = 0.5;
params.p18Final = -0.5;

params.gm17 = 4.0e-6;
params.gm18 = 4.0e-6;
params.gP17 = 1.5e-6;
params.gP18 = 1.5e-6;
params.kGamma17 = 0.8;
params.kGamma18 = 0.8;
params.tauGamma17 = 3.0e-6;
params.tauGamma18 = 3.0e-6;

params.cQbar = 2.0e-12;
params.cQ = 2.0e-12;
params.gds17 = 2.0e-6;
params.gds18 = 2.0e-6;
params.g20 = 4.0e-6;
params.g19 = 4.0e-6;

params.b17 = 0.10;
params.b18 = 0.10;
params.tauB17 = 2.0e-6;
params.tauB18 = 2.0e-6;
end

function createTransferDiagram(modelName, params)
block = @(name) [modelName '/' name];

add_block('simulink/Sources/Step', block('P17 step'), ...
    'Time', num2str(params.p17StepTime), ...
    'Before', '0', ...
    'After', num2str(params.p17Final), ...
    'Position', [40 115 75 145]);
add_block('simulink/Sources/Step', block('P18 step'), ...
    'Time', num2str(params.p18StepTime), ...
    'Before', '0', ...
    'After', num2str(params.p18Final), ...
    'Position', [40 355 75 385]);

addTfBlock(block('B17(s): P17 to Qbar'), params.b17, params.tauB17, [135 105 245 155]);
addTfBlock(block('B18(s): P18 to Q'), params.b18, params.tauB18, [135 345 245 395]);

[num17, den17] = branchTf(params.gm17, params.gP17, params.kGamma17, ...
    params.tauGamma17, params.cQbar, params.gds17 + params.g20);
[num18, den18] = branchTf(params.gm18, params.gP18, params.kGamma18, ...
    params.tauGamma18, params.cQ, params.gds18 + params.g19);

add_block('simulink/Continuous/Transfer Fcn', block('G17(s): Q to Qbar'), ...
    'Numerator', mat2str(num17), ...
    'Denominator', mat2str(den17), ...
    'Position', [135 210 270 260]);
add_block('simulink/Continuous/Transfer Fcn', block('G18(s): Qbar to Q'), ...
    'Numerator', mat2str(num18), ...
    'Denominator', mat2str(den18), ...
    'Position', [550 210 685 260]);

add_block('simulink/Math Operations/Sum', block('Qbar sum'), ...
    'Inputs', '++', ...
    'Position', [335 135 365 235]);
add_block('simulink/Math Operations/Sum', block('Q sum'), ...
    'Inputs', '++', ...
    'Position', [765 135 795 235]);
add_block('simulink/Math Operations/Sum', block('DeltaVQ = Q - Qbar'), ...
    'Inputs', '+-', ...
    'Position', [850 300 880 360]);

add_block('simulink/Signal Routing/Mux', block('scope mux'), ...
    'Inputs', '3', ...
    'Position', [930 150 935 235]);
add_block('simulink/Sinks/Scope', block('Q and DeltaVQ scope'), ...
    'Position', [1000 155 1155 235]);

addWorkspaceSink(block('to_V_Qbar'), 'V_Qbar', [455 120 570 150]);
addWorkspaceSink(block('to_V_Q'), 'V_Q', [845 120 960 150]);
addWorkspaceSink(block('to_DeltaVQ'), 'DeltaVQ', [930 315 1045 345]);

add_line(modelName, 'P17 step/1', 'B17(s): P17 to Qbar/1', 'autorouting', 'on');
add_line(modelName, 'B17(s): P17 to Qbar/1', 'Qbar sum/1', 'autorouting', 'on');
add_line(modelName, 'Qbar sum/1', 'to_V_Qbar/1', 'autorouting', 'on');
add_line(modelName, 'Qbar sum/1', 'G18(s): Qbar to Q/1', 'autorouting', 'on');
add_line(modelName, 'G18(s): Qbar to Q/1', 'Q sum/1', 'autorouting', 'on');

add_line(modelName, 'P18 step/1', 'B18(s): P18 to Q/1', 'autorouting', 'on');
add_line(modelName, 'B18(s): P18 to Q/1', 'Q sum/2', 'autorouting', 'on');
add_line(modelName, 'Q sum/1', 'to_V_Q/1', 'autorouting', 'on');
add_line(modelName, 'Q sum/1', 'G17(s): Q to Qbar/1', 'autorouting', 'on');
add_line(modelName, 'G17(s): Q to Qbar/1', 'Qbar sum/2', 'autorouting', 'on');

add_line(modelName, 'Q sum/1', 'DeltaVQ = Q - Qbar/1', 'autorouting', 'on');
add_line(modelName, 'Qbar sum/1', 'DeltaVQ = Q - Qbar/2', 'autorouting', 'on');
add_line(modelName, 'DeltaVQ = Q - Qbar/1', 'to_DeltaVQ/1', 'autorouting', 'on');

add_line(modelName, 'Qbar sum/1', 'scope mux/1', 'autorouting', 'on');
add_line(modelName, 'Q sum/1', 'scope mux/2', 'autorouting', 'on');
add_line(modelName, 'DeltaVQ = Q - Qbar/1', 'scope mux/3', 'autorouting', 'on');
add_line(modelName, 'scope mux/1', 'Q and DeltaVQ scope/1', 'autorouting', 'on');

text = sprintf([ ...
    'Transfer-function diagram for 2T-2FeTFT dynamic cell\n', ...
    'G17(s)=V_Qbar/V_Q, G18(s)=V_Q/V_Qbar; both branches are inverting.\n', ...
    'Polarization enters through B17(s)P17 and B18(s)P18. Hold/read stability requires |G17(0)G18(0)| < 1.']);
annotation = Simulink.Annotation(modelName, text);
annotation.Position = [35 25 700 85];

set_param(modelName, 'ZoomFactor', 'FitSystem');
end

function [num, den] = branchTf(gm, gP, kGamma, tauGamma, cap, conductance)
% Fold gm + gP*kGamma/(tauGamma*s+1) over cap*s + conductance.
num = [-gm * tauGamma, -(gm + gP * kGamma)];
den = [tauGamma * cap, tauGamma * conductance + cap, conductance];
end

function addTfBlock(path, gain, tau, position)
add_block('simulink/Continuous/Transfer Fcn', path, ...
    'Numerator', mat2str(gain), ...
    'Denominator', mat2str([tau, 1]), ...
    'Position', position);
end

function addWorkspaceSink(path, variableName, position)
add_block('simulink/Sinks/To Workspace', path, ...
    'VariableName', variableName, ...
    'SaveFormat', 'Structure With Time', ...
    'Position', position);
end

function gain = dcLoopGain(params)
g17 = -(params.gm17 + params.gP17 * params.kGamma17) / (params.gds17 + params.g20);
g18 = -(params.gm18 + params.gP18 * params.kGamma18) / (params.gds18 + params.g19);
gain = g17 * g18;
end

function exportDiagram(modelName, diagramFile)
try
    print(['-s' modelName], '-dpng', '-r160', diagramFile);
catch warningInfo
    warning('Could not export Simulink diagram PNG: %s', warningInfo.message);
end
end
