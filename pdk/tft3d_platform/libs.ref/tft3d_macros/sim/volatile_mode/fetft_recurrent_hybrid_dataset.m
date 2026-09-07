function recurrentHybridInput = fetft_recurrent_hybrid_dataset(tStop, dt, cfg)
%FETFT_RECURRENT_HYBRID_DATASET Build recurrent hybrid write-hold-read data.
%
% Output matrix columns are:
%   time, followed by fetft_recurrent_hybrid_signal_names().
%
% Paper basis:
%   - Ni et al. use a dynamic history-aware Preisach model for WRITE,
%     including saturation branches, minor-loop history, and RC-delayed
%     effective FE voltage.
%   - Mo et al. use Preisach for initialization/program/erase and NLS for
%     retention, updating the FE voltage during short retention intervals.
%   - Gong et al. apply NLS to HfO2 capacitors, where switching is dominated
%     by reversed-domain nucleation and retention is driven by a
%     depolarization field that weakens as polarization decreases.
%
% This is still a compact bitcell abstraction: the NLS state is represented
% by eight normalized domain-population bins for each FeTFT branch.

if nargin < 1 || isempty(tStop)
    tStop = 80e-6;
end

if nargin < 2 || isempty(dt)
    dt = 5e-8;
end

if nargin < 3 || isempty(cfg)
    cfg = struct();
end

params = default_params(dt);
params = apply_config(params, cfg);
time = (0:dt:tStop).';
signals = fetft_recurrent_hybrid_signal_names();
values = zeros(numel(time), numel(signals));

if isfield(cfg, 'initialF17')
    f17State = min(max(sanitize_domain_vector(cfg.initialF17, params), 0.0), 1.0);
else
    f17State = initial_domains(0.0, params);
end
if isfield(cfg, 'initialF18')
    f18State = min(max(sanitize_domain_vector(cfg.initialF18, params), 0.0), 1.0);
else
    f18State = initial_domains(0.0, params);
end
history17 = initial_history();
history18 = initial_history();
row = 1;

if isfield(cfg, 'segments')
    segments = cfg.segments;
else
    segments = default_segments();
end

for segIdx = 1:size(segments, 1)
    phase = segments(segIdx, 1);
    command = segments(segIdx, 2);
    t0 = segments(segIdx, 3);
    t1 = segments(segIdx, 4);

    if row > numel(time)
        break;
    end

    pStart17 = domain_p(f17State, params);
    pStart18 = domain_p(f18State, params);
    dPStart = pStart17 - pStart18;

    while row <= numel(time) && time(row) >= t0 - 0.5 * dt && time(row) < t1 - 0.5 * dt
        tLocal = time(row) - t0;

        if phase == 1
            [sample, f17State, f18State, history17, history18] = write_sample( ...
                tLocal, command, pStart17, pStart18, f17State, f18State, ...
                history17, history18, params);
        else
            isRead = phase == 3;
            [sample, f17State, f18State] = retention_sample( ...
                phase, command, tLocal, dPStart, f17State, f18State, ...
                history17, history18, isRead, params);
        end

        values(row, :) = sample;
        row = row + 1;
    end
end

while row <= numel(time)
    dPStart = domain_p(f17State, params) - domain_p(f18State, params);
    [values(row, :), f17State, f18State] = retention_sample( ...
        2, 0, time(row) - segments(end, 3), dPStart, f17State, f18State, ...
        history17, history18, false, params);
    row = row + 1;
end

recurrentHybridInput = [time, values];
end

function params = default_params(dt)
params.dt = dt;
params.vWrite = 2.4;
params.tauVeff = 0.28e-6;
params.pSat = 1.0;
params.alphaPreisach = 1.55;
params.vCoercive = 0.85;
params.minorScale = 0.78;

params.nDomains = 8;
params.domainWeights = ones(1, params.nDomains) / params.nDomains;
params.nlsTau0 = 0.65e-6;
params.nlsExponent = 1.35;
params.activationVoltage = linspace(0.42, 0.92, params.nDomains);
params.kDep = 1.0;
params.eHold = 0.0;
params.eImp = 0.0;
params.vFieldFloor = 1e-3;
params.maxRate = 3.0e6;
params.trapAccel = 0.18;
params.tauTrap = 25e-6;
params.retentionEnable = true;
params.programmingEnable = true;
params.fixedRateEnable = false;
params.fixedRPlus = zeros(1, params.nDomains);
params.fixedRMinus = zeros(1, params.nDomains);

params.aWrite = 0.25;
params.aHold = 0.35;
params.aRead = 0.88;
params.bWrite = 0.06;
params.bHold = 0.04;
params.bRead = 0.06;
params.vMin = 0.12;
end

function params = apply_config(params, cfg)
params = set_scalar_field(params, cfg, 'retentionEnable', 'retention_enable');
params = set_scalar_field(params, cfg, 'programmingEnable', 'programming_enable');
params = set_scalar_field(params, cfg, 'kDep', 'K_dep');
params = set_scalar_field(params, cfg, 'eHold', 'E_hold');
params = set_scalar_field(params, cfg, 'eImp', 'E_imp');
params = set_scalar_field(params, cfg, 'vFieldFloor', 'V_field_floor');
params = set_scalar_field(params, cfg, 'maxRate', 'max_rate');
params = set_scalar_field(params, cfg, 'trapAccel', 'trap_accel');
params = set_scalar_field(params, cfg, 'tauTrap', 'tau_trap');
params = set_scalar_field(params, cfg, 'fixedRateEnable', 'fixed_rate_enable');

if isfield(cfg, 'domainWeights')
    params.domainWeights = sanitize_weight_vector(cfg.domainWeights, params.nDomains);
end
if isfield(cfg, 'activationVoltage')
    params.activationVoltage = max(sanitize_domain_vector(cfg.activationVoltage, params), 0.0);
end
if isfield(cfg, 'fixedRPlus')
    params.fixedRPlus = max(sanitize_domain_vector(cfg.fixedRPlus, params), 0.0);
end
if isfield(cfg, 'fixedRMinus')
    params.fixedRMinus = max(sanitize_domain_vector(cfg.fixedRMinus, params), 0.0);
end
end

function params = set_scalar_field(params, cfg, canonicalName, aliasName)
if isfield(cfg, canonicalName)
    params.(canonicalName) = cfg.(canonicalName);
elseif isfield(cfg, aliasName)
    params.(canonicalName) = cfg.(aliasName);
end
end

function weights = sanitize_weight_vector(values, nDomains)
weights = zeros(1, nDomains);
count = min(numel(values), nDomains);
weights(1:count) = reshape(values(1:count), 1, count);
weights = max(weights, 0.0);
total = sum(weights);
if total <= 0.0
    weights(:) = 1.0 / nDomains;
else
    weights = weights ./ total;
end
end

function values = sanitize_domain_vector(inputValues, params)
values = zeros(1, params.nDomains);
count = min(numel(inputValues), params.nDomains);
values(1:count) = reshape(inputValues(1:count), 1, count);
end

function segments = default_segments()
segments = [ ...
    1,  1, 0e-6,  2e-6; ...
    2,  0, 2e-6, 22e-6; ...
    3,  0, 22e-6, 24e-6; ...
    1, -1, 24e-6, 26e-6; ...
    2,  0, 26e-6, 46e-6; ...
    3,  0, 46e-6, 48e-6; ...
    1,  1, 48e-6, 50e-6; ...
    2,  0, 50e-6, 70e-6; ...
    3,  0, 70e-6, 72e-6; ...
    2,  0, 72e-6, 80e-6];
end

function history = initial_history()
history.branch = 0.0;
history.turnV = 0.0;
history.turnP = 0.0;
history.depth = 0.0;
end

function f = initial_domains(p, params)
f = adjust_domain_population(0.5 * ones(1, params.nDomains), p, 1, params);
end

function [sample, f17, f18, history17, history18] = write_sample( ...
    tLocal, command, pStart17, pStart18, f17, f18, history17, history18, params)
vProg17 = command * params.vWrite;
vProg18 = -command * params.vWrite;
vEff17 = delayed_voltage(vProg17, tLocal, params.tauVeff);
vEff18 = delayed_voltage(vProg18, tLocal, params.tauVeff);

if params.programmingEnable
    pTarget17 = preisach_target(vEff17, params);
    pTarget18 = preisach_target(vEff18, params);
    p17Preisach = minor_loop_update(pStart17, pTarget17, params);
    p18Preisach = minor_loop_update(pStart18, pTarget18, params);

    f17 = adjust_domain_population(f17, p17Preisach, sign_nonzero(vProg17), params);
    f18 = adjust_domain_population(f18, p18Preisach, sign_nonzero(vProg18), params);
else
    pTarget17 = pStart17;
    pTarget18 = pStart18;
    p17Preisach = pStart17;
    p18Preisach = pStart18;
end
p17 = domain_p(f17, params);
p18 = domain_p(f18, params);

if params.programmingEnable
    history17 = update_history(history17, sign_nonzero(vProg17), vEff17, pStart17, p17);
    history18 = update_history(history18, sign_nonzero(vProg18), vEff18, pStart18, p18);
end

dPProgrammed = p17 - p18;
retentionFactor = 1.0;
dP = dPProgrammed;
a = params.aWrite;
b = params.bWrite;
[polarizationGain, dVQ, senseMargin, refreshNeeded] = readout(dP, a, b, params.vMin);

zeroRates = zeros(1, params.nDomains);
sample = pack_sample(1.0, command, vEff17, vEff18, pStart17, pStart18, ...
    pTarget17, pTarget18, p17Preisach, p18Preisach, p17, p18, ...
    dPProgrammed, retentionFactor, dP, a, polarizationGain, dVQ, ...
    senseMargin, refreshNeeded, f17, f18, zeroRates, zeroRates, ...
    zeroRates, zeroRates, 0.0, 0.0, 0.0, 0.0, params.eHold, ...
    params.eHold, params.eImp, params.eImp, history17, history18, ...
    params.programmingEnable, params.retentionEnable);
end

function [sample, f17, f18] = retention_sample( ...
    phase, command, tLocal, dPStart, f17, f18, history17, history18, isRead, params)
step = params.dt * double(tLocal > 0.0);

[f17, rPlus17, rMinus17, vFe17, eDep17, eHold17, eImp17] = ...
    nls_retention_step(f17, tLocal, step, params);
[f18, rPlus18, rMinus18, vFe18, eDep18, eHold18, eImp18] = ...
    nls_retention_step(f18, tLocal, step, params);

p17 = domain_p(f17, params);
p18 = domain_p(f18, params);
pTarget17 = p17;
pTarget18 = p18;
p17Preisach = p17;
p18Preisach = p18;
dP = p17 - p18;
if abs(dPStart) > 1e-12
    retentionFactor = dP / dPStart;
else
    retentionFactor = 1.0;
end
dPProgrammed = dPStart;

if isRead
    a = params.aRead;
    b = params.bRead;
else
    a = params.aHold;
    b = params.bHold;
end

[polarizationGain, dVQ, senseMargin, refreshNeeded] = readout(dP, a, b, params.vMin);

sample = pack_sample(phase, command, 0.0, 0.0, p17, p18, ...
    pTarget17, pTarget18, p17Preisach, p18Preisach, p17, p18, ...
    dPProgrammed, retentionFactor, dP, a, polarizationGain, dVQ, ...
    senseMargin, refreshNeeded, f17, f18, rPlus17, rMinus17, ...
    rPlus18, rMinus18, vFe17, vFe18, eDep17, eDep18, eHold17, ...
    eHold18, eImp17, eImp18, history17, history18, ...
    params.programmingEnable, params.retentionEnable);
end

function sample = pack_sample(phase, command, vEff17, vEff18, pStart17, pStart18, ...
    pTarget17, pTarget18, p17Preisach, p18Preisach, p17, p18, ...
    dPProgrammed, retentionFactor, dP, loopGain, polarizationGain, dVQ, ...
    senseMargin, refreshNeeded, f17, f18, rPlus17, rMinus17, rPlus18, ...
    rMinus18, vFe17, vFe18, eDep17, eDep18, eHold17, eHold18, ...
    eImp17, eImp18, history17, history18, programmingEnable, retentionEnable)
sample = [phase, command, vEff17, vEff18, ...
    pStart17, pStart18, pTarget17, pTarget18, ...
    p17Preisach, p18Preisach, p17, p18, ...
    dPProgrammed, retentionFactor, dP, ...
    loopGain, polarizationGain, dVQ, senseMargin, refreshNeeded, ...
    f17, f18, rPlus17, rMinus17, rPlus18, rMinus18, ...
    vFe17, vFe18, eDep17, eDep18, eHold17, eHold18, eImp17, eImp18, ...
    history17.branch, history18.branch, history17.turnV, history18.turnV, ...
    history17.turnP, history18.turnP, history17.depth, history18.depth, ...
    double(programmingEnable), double(retentionEnable)];
end

function [fNext, rPlus, rMinus, vFe, eDep, eHold, eImp] = nls_retention_step(f, tLocal, step, params)
p = domain_p(f, params);
eDep = -params.kDep * p;
eHold = params.eHold;
eImp = params.eImp;
vFe = eDep + eHold + eImp;

if ~params.retentionEnable
    rPlus = zeros(1, params.nDomains);
    rMinus = zeros(1, params.nDomains);
    fNext = f;
    return;
end

[rPlus, rMinus] = nls_rates(vFe, tLocal, params);

df = ((1.0 - f) .* rPlus - f .* rMinus) * step;
fNext = min(max(f + df, 0.0), 1.0);
end

function [rPlus, rMinus] = nls_rates(vFe, tLocal, params)
if params.fixedRateEnable
    rPlus = params.fixedRPlus;
    rMinus = params.fixedRMinus;
    return;
end

vAbs = max(abs(vFe), params.vFieldFloor);
tau = params.nlsTau0 .* exp((params.activationVoltage ./ vAbs) .^ params.nlsExponent);
trapMultiplier = 1.0 + params.trapAccel * (1.0 - exp(-max(tLocal, 0.0) / params.tauTrap));
rate = min(params.maxRate, trapMultiplier ./ tau);

if vFe > 0.0
    rPlus = rate;
    rMinus = zeros(size(rate));
elseif vFe < 0.0
    rPlus = zeros(size(rate));
    rMinus = rate;
else
    rPlus = zeros(size(rate));
    rMinus = zeros(size(rate));
end
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

function p = domain_p(f, params)
p = sum(params.domainWeights .* (2.0 .* f - 1.0));
end

function f = adjust_domain_population(f, pTarget, direction, params)
targetOccupancy = min(max((pTarget + 1.0) / 2.0, 0.0), 1.0);
currentOccupancy = sum(params.domainWeights .* f);
delta = targetOccupancy - currentOccupancy;

if abs(delta) <= 1e-12
    return;
end

if direction >= 0
    order = 1:params.nDomains;
else
    order = params.nDomains:-1:1;
end

if delta < 0.0
    order = fliplr(order);
end

for idx = order
    weight = params.domainWeights(idx);
    if weight <= 0.0
        continue;
    end

    if delta > 0.0
        capacity = (1.0 - f(idx)) * weight;
        change = min(capacity, delta);
        f(idx) = f(idx) + change / weight;
        delta = delta - change;
    else
        capacity = f(idx) * weight;
        change = min(capacity, -delta);
        f(idx) = f(idx) - change / weight;
        delta = delta + change;
    end

    if abs(delta) <= 1e-12
        break;
    end
end

f = min(max(f, 0.0), 1.0);
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

function [polarizationGain, dVQ, senseMargin, refreshNeeded] = readout(dP, a, b, vMin)
if a >= 1.0
    a = 0.999999;
end

polarizationGain = b / (1.0 - a);
dVQ = polarizationGain * dP;
senseMargin = abs(dVQ) - vMin;
refreshNeeded = double(senseMargin < 0.0);
end
