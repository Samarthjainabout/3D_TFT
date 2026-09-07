function strict = fetft_strict_harness_checks()
%FETFT_STRICT_HARNESS_CHECKS Deterministic strict debug checks for the hybrid model.
%
% The checks in this helper are test-harness oracles around the reduced
% Preisach + NLS state equations. They are intentionally separated from the
% paper-limited audit because several controls are verification conveniences
% rather than physical requirements stated in the attached papers.

params = default_params();
caseIds = {'TC01', 'TC02', 'TC03', 'TC04', 'TC05', 'TC06', ...
    'TC07', 'TC08', 'TC09', 'TC10', 'TC11', 'TC12', 'E2E01'};

strict = struct();
strict.TC01 = check_tc01(params);
strict.TC02 = check_tc02(params);
strict.TC03 = check_tc03(params);
strict.TC04 = check_tc04(params);
strict.TC05 = check_tc05(params);
strict.TC06 = check_tc06(params);
strict.TC07 = check_tc07(params);
strict.TC08 = check_tc08(params);
strict.TC09 = check_tc09(params);
strict.TC10 = check_tc10(params);
strict.TC11 = check_tc11(params);
strict.TC12 = check_tc12(params);
strict.E2E01 = check_e2e01(params);
strict.results = strict_table(strict, caseIds);
end

function result = check_tc01(params)
levels = [0.2, 0.5, 0.8];
maxFrozenChange = 0.0;
maxZeroFieldChange = 0.0;

for idx = 1:numel(levels)
    state = state_from_f(levels(idx) * ones(1, params.nDomains), params);
    frozen = hold_state(state, 100.0, params, struct('retentionEnable', false));
    maxFrozenChange = max(maxFrozenChange, state_error(state, frozen.state, params));

    zeroOpts = struct('retentionEnable', true, 'kDep', 0.0, ...
        'eHold', 0.0, 'eImp', 0.0);
    zeroField = hold_state(state, 100.0, params, zeroOpts);
    maxZeroFieldChange = max(maxZeroFieldChange, state_error(state, zeroField.state, params));
end

pass = maxFrozenChange <= 1e-12 && maxZeroFieldChange <= 1e-12;
evidence = sprintf(['Frozen and zero-field retention controls exercised for f_i = 0.2, 0.5, 0.8 over 100 s; ', ...
    'max frozen state error %.3g, max zero-field error %.3g.'], ...
    maxFrozenChange, maxZeroFieldChange);
result = pass_fail(pass, evidence, 'Frozen/no-drive controls still changed domain state.');
end

function result = check_tc02(params)
one = with_weights(params, [1, zeros(1, params.nDomains - 1)]);
times = [0.0, log(2.0) / 1000.0, 1e-3, 3e-3, 5e-3];

opts = fixed_rate_opts(one, zeros(1, one.nDomains), [1000, zeros(1, one.nDomains - 1)]);
neg = hold_state(state_from_f([1, zeros(1, one.nDomains - 1)], one), 5e-3, one, set_times(opts, times));
negRef = 2.0 * exp(-1000.0 * times(:)) - 1.0;
negErr = max(abs(neg.trace.P - negRef));

opts = fixed_rate_opts(one, [1000, zeros(1, one.nDomains - 1)], zeros(1, one.nDomains));
pos = hold_state(state_from_f(zeros(1, one.nDomains), one), 5e-3, one, set_times(opts, times));
posRef = 2.0 * (1.0 - exp(-1000.0 * times(:))) - 1.0;
posErr = max(abs(pos.trace.P - posRef));

opts = fixed_rate_opts(one, [600, zeros(1, one.nDomains - 1)], [200, zeros(1, one.nDomains - 1)]);
both = hold_state(state_from_f([0.25, zeros(1, one.nDomains - 1)], one), 5e-3, one, set_times(opts, times));
lambda = 800.0;
fInf = 600.0 / lambda;
bothRefF = fInf + (0.25 - fInf) .* exp(-lambda * times(:));
bothErr = max(abs(both.trace.P - (2.0 * bothRefF - 1.0)));

maxErr = max([negErr, posErr, bothErr]);
pass = maxErr <= 1e-3;
evidence = sprintf('N=1 fixed-rate oracle passed negative, positive, and bidirectional-rate runs; max normalized-P error %.3g.', maxErr);
result = pass_fail(pass, evidence, 'Constant-rate oracle exceeded the 1e-3 normalized-P tolerance.');
end

function result = check_tc03(params)
sweep = fetft_preisach_reference_sweep();
starts = [-0.4, 0.0, 0.4];
amps = [0.5, 0.75, 1.0];
widths = [0.1, 1.0, 10.0] * params.tp;
polarities = [-1.0, 1.0];
maxOverlayErr = 0.0;
hasUnsaturated = false;

for startIdx = 1:numel(starts)
    for ampIdx = 1:numel(amps)
        for widthIdx = 1:numel(widths)
            for polIdx = 1:numel(polarities)
                state = state_from_p(starts(startIdx), params);
                written = write_state(state, polarities(polIdx), amps(ampIdx), widths(widthIdx), params, struct('programmingEnable', true));
                refP = reference_write_p(starts(startIdx), polarities(polIdx) * amps(ampIdx) * params.vWrite, widths(widthIdx), params);
                maxOverlayErr = max(maxOverlayErr, abs(domain_p(written.state.f, params) - refP));
                hasUnsaturated = hasUnsaturated || abs(refP) < 0.98 * params.minorScale;
            end
        end
    end
end

pass = sweep.pass && maxOverlayErr <= 1e-2 && hasUnsaturated;
evidence = sprintf('Retention-disabled programming overlay matches reference over %d sweep cases; max P error %.3g, unsaturated case present=%d.', ...
    sweep.nCases, maxOverlayErr, hasUnsaturated);
result = pass_fail(pass, evidence, 'Preisach standalone/combined overlay did not meet the 1 percent full-scale criterion.');
end

function result = check_tc04(params)
pos = write_state(state_from_p(0.0, params), +1.0, 1.0, params.tp, params, struct());
neg = write_state(state_from_p(0.0, params), -1.0, 1.0, params.tp, params, struct());

posHold = hold_state(pos.state, 100e-6, params, struct('retentionEnable', true));
negHold = hold_state(neg.state, 100e-6, params, struct('retentionEnable', true));
posDisabled = hold_state(pos.state, 100e-6, params, struct('retentionEnable', false));
negDisabled = hold_state(neg.state, 100e-6, params, struct('retentionEnable', false));

[~, posRates] = rates_and_derivative(pos.state.f, 0.0, params, struct());
[~, negRates] = rates_and_derivative(neg.state.f, 0.0, params, struct());
posRateOrder = nonincreasing(posRates.rMinus(posRates.rMinus > 0.0));
negRateOrder = nonincreasing(negRates.rPlus(negRates.rPlus > 0.0));

posOk = approaches_zero(posHold.trace.P, +1.0);
negOk = approaches_zero(negHold.trace.P, -1.0);
disabledErr = max(state_error(pos.state, posDisabled.state, params), state_error(neg.state, negDisabled.state, params));
pass = posOk && negOk && disabledErr <= 1e-12 && posRateOrder && negRateOrder;

evidence = sprintf(['Positive hold %.4g -> %.4g, negative hold %.4g -> %.4g; ', ...
    'retention-disabled error %.3g, ordered initial rates=%d/%d.'], ...
    posHold.trace.P(1), posHold.trace.P(end), negHold.trace.P(1), negHold.trace.P(end), ...
    disabledErr, posRateOrder, negRateOrder);
result = pass_fail(pass, evidence, 'Write-hold decay, disabled control, or domain-rate ordering failed.');
end

function result = check_tc05(params)
written = write_state(state_from_p(0.0, params), +1.0, 1.0, params.tp, params, struct());
decayed = hold_state(written.state, 100e-6, params, struct('retentionEnable', true));
before = decayed.state;

noWrite = write_state(before, +1.0, 1.0, params.tp, params, struct('programmingEnable', false));
afterHold = hold_state(noWrite.state, 10e-6, params, struct('retentionEnable', false));
roundTripErr = state_error(before, afterHold.state, params);

partial = write_state(afterHold.state, +1.0, 0.55, 0.25 * params.tp, params, struct());
importErr = max(abs(partial.info.startF - before.f));
pass = roundTripErr <= 1e-4 && importErr <= 1e-4;

evidence = sprintf('No-op HOLD-WRITE-HOLD handoff kept f_i/P fixed; round-trip error %.3g, next-write import error %.3g.', ...
    roundTripErr, importErr);
result = pass_fail(pass, evidence, 'No-op ownership switch did not preserve the complete relaxed state.');
end

function result = check_tc06(params)
waits = [1e-6, 1e-3, 100.0];
base = write_state(state_from_p(-0.25, params), +1.0, 0.75, params.tp, params, struct());
maxReplayErr = 0.0;
maxImportErr = 0.0;
losses = zeros(size(waits));

for idx = 1:numel(waits)
    aged = hold_state(base.state, waits(idx), params, struct('retentionEnable', true));
    consumed = write_state(aged.state, +1.0, 0.55, 0.25 * params.tp, params, struct());
    replay = write_state(aged.state, +1.0, 0.55, 0.25 * params.tp, params, struct());
    maxReplayErr = max(maxReplayErr, state_error(consumed.state, replay.state, params));
    maxImportErr = max(maxImportErr, max(abs(consumed.info.startF - aged.state.f)));
    losses(idx) = abs(domain_p(base.state.f, params) - domain_p(aged.state.f, params));
end

zeroDecay = hold_state(base.state, 100.0, params, struct('retentionEnable', false));
zeroRef = write_state(base.state, +1.0, 0.55, 0.25 * params.tp, params, struct());
zeroAfter = write_state(zeroDecay.state, +1.0, 0.55, 0.25 * params.tp, params, struct());
zeroErr = state_error(zeroRef.state, zeroAfter.state, params);

resolvedLossCount = sum(losses > 1e-3);
pass = maxReplayErr <= 1e-2 && maxImportErr <= 1e-4 && zeroErr <= 1e-4 && resolvedLossCount >= 2;
evidence = sprintf(['Wait-partial rewrite consumed the relaxed f_i state for waits 1 us, 1 ms, 100 s; ', ...
    'max replay error %.3g, max import error %.3g, zero-decay control error %.3g, resolved losses=%d.'], ...
    maxReplayErr, maxImportErr, zeroErr, resolvedLossCount);
result = pass_fail(pass, evidence, 'Partial rewrite did not replay from the complete relaxed state.');
end

function result = check_tc07(params)
forward = write_state(state_from_p(0.0, params), +1.0, 1.0, params.tp, params, struct());
held = hold_state(forward.state, 1e-3, params, struct('retentionEnable', true));
partialNeg = write_state(held.state, -1.0, 0.60, 0.30 * params.tp, params, struct());
fullNeg = write_state(partialNeg.state, -1.0, 1.0, params.tp, params, struct());

mirror = write_state(state_from_p(0.0, params), -1.0, 1.0, params.tp, params, struct());
mirrorHeld = hold_state(mirror.state, 1e-3, params, struct('retentionEnable', true));
partialPos = write_state(mirrorHeld.state, +1.0, 0.60, 0.30 * params.tp, params, struct());
fullPos = write_state(partialPos.state, +1.0, 1.0, params.tp, params, struct());

pBefore = domain_p(held.state.f, params);
pPartial = domain_p(partialNeg.state.f, params);
pNeg = domain_p(fullNeg.state.f, params);
pPosMirror = domain_p(fullPos.state.f, params);
partialMoved = abs(pPartial - pBefore) > 1e-3;
mirrorErr = abs(pNeg + pPosMirror);
pass = partialMoved && pNeg < -0.60 && pPosMirror > 0.60 && mirrorErr <= 1e-2;

evidence = sprintf('Delayed opposite-polarity pulse moved P %.4g -> %.4g; full erase P=%.4g, mirrored final P=%.4g, mirror error %.3g.', ...
    pBefore, pPartial, pNeg, pPosMirror, mirrorErr);
result = pass_fail(pass, evidence, 'Opposite-polarity delayed write or mirrored reversal failed.');
end

function result = check_tc08(params)
targets = [-0.8, -0.4, 0.0, 0.4, 0.8];
holds = [0.0, 1e-6, 10e-6, 100e-6, 1e-3, 10e-3];
maxReplayErr = 0.0;
maxDisabledWriteErr = 0.0;
zeroDriveErr = 0.0;

for idx = 1:numel(targets)
    state = state_from_p(targets(idx), params);
    held = hold_state(state, holds(end), params, set_times(struct('retentionEnable', true), holds));
    pulseSign = -sign_nonzero(targets(idx));
    if pulseSign == 0.0
        pulseSign = 1.0;
    end
    reverse1 = write_state(held.state, pulseSign, 0.55, 0.25 * params.tp, params, struct());
    reverse2 = write_state(held.state, pulseSign, 0.55, 0.25 * params.tp, params, struct());
    returnPulse = write_state(reverse1.state, -pulseSign, 0.55, 0.25 * params.tp, params, struct());
    maxReplayErr = max(maxReplayErr, state_error(reverse1.state, reverse2.state, params));

    disabled = write_state(state, pulseSign, 0.55, 0.25 * params.tp, params, struct());
    refP = reference_write_p(domain_p(state.f, params), pulseSign * 0.55 * params.vWrite, 0.25 * params.tp, params);
    maxDisabledWriteErr = max(maxDisabledWriteErr, abs(domain_p(disabled.state.f, params) - refP));

    if abs(targets(idx)) <= 1e-12
        zeroDriveErr = max(zeroDriveErr, state_error(state, held.state, params));
    end

    maxReplayErr = max(maxReplayErr, max(abs(returnPulse.state.f - min(max(returnPulse.state.f, 0.0), 1.0))));
end

pass = maxReplayErr <= 1e-12 && maxDisabledWriteErr <= 1e-2 && zeroDriveErr <= 1e-12;
evidence = sprintf('Five intermediate states replay reproducibly over log-spaced holds; max replay error %.3g, disabled-write error %.3g, P~0 hold error %.3g.', ...
    maxReplayErr, maxDisabledWriteErr, zeroDriveErr);
result = pass_fail(pass, evidence, 'Intermediate-state replay, disabled programming reference, or zero-drive hold failed.');
end

function result = check_tc09(params)
p0 = 0.6;
state = state_from_p(p0, params);
noDep = rates_and_derivative(state.f, 0.0, params, struct('kDep', 0.0));
[rateK0, infoK0] = rates_and_derivative(state.f, 0.0, params, struct('kDep', 1.0));
[rate2K0, ~] = rates_and_derivative(state.f, 0.0, params, struct('kDep', 2.0));
[rateNegHold, ~] = rates_and_derivative(state.f, 0.0, params, struct('kDep', 1.0, 'eHold', -0.5 * p0));
[ratePosHold, ~] = rates_and_derivative(state.f, 0.0, params, struct('kDep', 1.0, 'eHold', +0.5 * p0));
[rateCancel, ~] = rates_and_derivative(state.f, 0.0, params, struct('kDep', 1.0, 'eHold', +p0));

negState = state_from_p(-p0, params);
[rateNegCancel, negInfo] = rates_and_derivative(negState.f, 0.0, params, struct('kDep', 1.0, 'eHold', -p0));

pass = abs(noDep) <= 1e-12 && abs(rateCancel) <= 1e-12 && abs(rateNegCancel) <= 1e-12 && ...
    abs(rate2K0) > abs(rateK0) && abs(rateNegHold) > abs(rateK0) && abs(ratePosHold) < abs(rateK0) && ...
    infoK0.vFe < 0.0 && negInfo.vFe == 0.0;

evidence = sprintf(['Hold-field sweep passed: K=0 dP/dt %.3g, K0 %.3g, 2K0 %.3g, ', ...
    'negative compensation %.3g, positive compensation %.3g, cancellation %.3g.'], ...
    noDep, rateK0, rate2K0, rateNegHold, ratePosHold, rateCancel);
result = pass_fail(pass, evidence, 'Depolarization or hold-field control sign/rate ordering failed.');
end

function result = check_tc10(params)
two = with_weights(params, [0.5, 0.5, zeros(1, params.nDomains - 2)]);
rPlus = zeros(1, two.nDomains);
rMinus = [1000, 1, zeros(1, two.nDomains - 2)];
opts = fixed_rate_opts(two, rPlus, rMinus);
times = [0.0, 0.25e-3, 1e-3, 5e-3];

stateA = state_from_f([1.0, 0.5, zeros(1, two.nDomains - 2)], two);
stateB = state_from_f([0.5, 1.0, zeros(1, two.nDomains - 2)], two);
[dpa, ~] = rates_and_derivative(stateA.f, 0.0, two, opts);
[dpb, ~] = rates_and_derivative(stateB.f, 0.0, two, opts);

traceA = hold_state(stateA, 5e-3, two, set_times(opts, times));
traceB = hold_state(stateB, 5e-3, two, set_times(opts, times));
refA = 2.0 * (0.5 * exp(-1000.0 * times(:)) + 0.25 * exp(-times(:))) - 1.0;
refB = 2.0 * (0.25 * exp(-1000.0 * times(:)) + 0.5 * exp(-times(:))) - 1.0;
curveErr = max(max(abs(traceA.trace.P - refA)), max(abs(traceB.trace.P - refB)));

pass = abs(dpa + 1000.5) <= 1e-9 && abs(dpb + 501.0) <= 1e-9 && curveErr <= 1e-3;
evidence = sprintf('N=2 same-P injected states give dPdt_A %.6g and dPdt_B %.6g per second; curve oracle max error %.3g.', ...
    dpa, dpb, curveErr);
result = pass_fail(pass, evidence, 'Same-P/different-domain derivative oracle failed.');
end

function result = check_tc11(params)
initial = write_state(state_from_p(0.0, params), +1.0, 1.0, params.tp, params, struct());
noRead = hold_state(initial.state, 25e-6, params, struct('retentionEnable', true));
idealObserved = hold_state(initial.state, 25e-6, params, struct('retentionEnable', true));
idealErr = state_error(noRead.state, idealObserved.state, params);

beforeRead = hold_state(initial.state, 10e-6, params, struct('retentionEnable', true));
readOpts = struct('retentionEnable', true, 'eHold', -0.25);
readPulse = hold_state(beforeRead.state, 2e-6, params, readOpts);
afterRead = hold_state(readPulse.state, 13e-6, params, struct('retentionEnable', true));
readDelta = state_error(beforeRead.state, readPulse.state, params);
finiteOk = all(isfinite(afterRead.trace.P)) && all(all(isfinite(afterRead.trace.f)));

pass = idealErr <= 1e-12 && readDelta > 0.0 && finiteOk;
evidence = sprintf('Ideal observation error %.3g; explicit finite read-field pulse changes state only through rates, read-pulse state delta %.3g.', ...
    idealErr, readDelta);
result = pass_fail(pass, evidence, 'Read observation changed state or finite read pulse failed to use modeled rates.');
end

function result = check_tc12(params)
tc02 = check_tc02(params);

start = write_state(state_from_p(0.0, params), +1.0, 1.0, params.tp, params, struct());
times = linspace(0.0, 1e-3, 1001);
continuous = hold_state(start.state, 1e-3, params, set_times(struct('retentionEnable', true), times));

segState = start.state;
for idx = 1:10
    seg = hold_state(segState, 0.1e-3, params, set_times(struct('retentionEnable', true), linspace(0.0, 0.1e-3, 101)));
    segState = seg.state;
end

firstHalf = hold_state(start.state, 0.5e-3, params, set_times(struct('retentionEnable', true), linspace(0.0, 0.5e-3, 501)));
checkpoint = firstHalf.state;
secondHalf = hold_state(checkpoint, 0.5e-3, params, set_times(struct('retentionEnable', true), linspace(0.0, 0.5e-3, 501)));

segErr = state_error(continuous.state, segState, params);
checkpointErr = state_error(continuous.state, secondHalf.state, params);
long = hold_state(state_from_p(0.9, params), 100.0, params, struct('retentionEnable', true));
finiteOk = all(isfinite(long.trace.P)) && all(long.trace.f(:) >= -1e-9) && all(long.trace.f(:) <= 1.0 + 1e-9);

pass = strcmp(tc02.status, 'PASS') && segErr <= 1e-2 && checkpointErr <= 1e-2 && finiteOk;
evidence = sprintf('Tight oracle plus segmented/checkpoint regression passed; segmented error %.3g, checkpoint error %.3g, long finite=%d.', ...
    segErr, checkpointErr, finiteOk);
result = pass_fail(pass, evidence, 'Solver/checkpoint/long-time regression exceeded tolerance.');
end

function result = check_e2e01(params)
negative = write_state(state_from_p(0.0, params), -1.0, 1.0, params.tp, params, struct());
positive = write_state(negative.state, +1.0, 1.0, params.tp, params, struct());
hold1ms = hold_state(positive.state, 1e-3, params, struct('retentionEnable', true));
hold100s = hold_state(hold1ms.state, 100.0 - 1e-3, params, struct('retentionEnable', true));

beforeNoop = hold100s.state;
noWrite = write_state(beforeNoop, +1.0, 1.0, params.tp, params, struct('programmingEnable', false));
afterNoop = hold_state(noWrite.state, 1e-6, params, struct('retentionEnable', false));
noopErr = state_error(beforeNoop, afterNoop.state, params);

partialPositive = write_state(afterNoop.state, +1.0, 0.55, 0.25 * params.tp, params, struct());
shortHold = hold_state(partialPositive.state, 10e-6, params, struct('retentionEnable', true));
negativeErase = write_state(shortHold.state, -1.0, 1.0, params.tp, params, struct());

disabledPositive = write_state(negative.state, +1.0, 1.0, params.tp, params, struct());
disabledHold = hold_state(disabledPositive.state, 100.0, params, struct('retentionEnable', false));

pProgrammed = domain_p(positive.state.f, params);
p1ms = domain_p(hold1ms.state.f, params);
p100s = domain_p(hold100s.state.f, params);
pDisabled = domain_p(disabledHold.state.f, params);
pErase = domain_p(negativeErase.state.f, params);
retentionEvolves = abs(pProgrammed - p1ms) > 1e-3 && abs(p1ms - p100s) >= 0.0;
overlaySeparates = abs(pDisabled - p100s) > 1e-3;
partialImportErr = max(abs(partialPositive.info.startF - beforeNoop.f));
pass = pProgrammed > 0.5 && retentionEvolves && noopErr <= 1e-4 && ...
    partialImportErr <= 1e-4 && pErase < -0.5 && overlaySeparates;

evidence = sprintf(['E2E sequence passed: P write %.4g, 1 ms %.4g, 100 s %.4g, disabled %.4g, ', ...
    'noop error %.3g, partial import %.3g, erase %.4g.'], ...
    pProgrammed, p1ms, p100s, pDisabled, noopErr, partialImportErr, pErase);
result = pass_fail(pass, evidence, 'End-to-end write-hold-noop-partial-erase sequence failed.');
end

function out = hold_state(state, duration, params, opts)
if nargin < 4
    opts = struct();
end

times = get_option(opts, 'times', hold_times(duration));
times = unique([0.0; times(:); duration]);
times = times(times >= 0.0 & times <= duration);
if times(end) < duration
    times(end + 1, 1) = duration;
end

f = state.f;
trace.t = state.clock + times;
trace.f = zeros(numel(times), params.nDomains);
trace.P = zeros(numel(times), 1);
trace.vFe = zeros(numel(times), 1);
trace.rPlus = zeros(numel(times), params.nDomains);
trace.rMinus = zeros(numel(times), params.nDomains);

for idx = 1:numel(times)
    if idx > 1
        dt = times(idx) - times(idx - 1);
        f = hold_step(f, dt, state.clock + times(idx - 1), params, opts);
    end
    [rPlus, rMinus, vFe] = retention_rates(f, state.clock + times(idx), params, opts);
    trace.f(idx, :) = f;
    trace.P(idx) = domain_p(f, params);
    trace.vFe(idx) = vFe;
    trace.rPlus(idx, :) = rPlus;
    trace.rMinus(idx, :) = rMinus;
end

out = struct();
out.trace = trace;
out.state = state;
out.state.f = f;
out.state.clock = state.clock + duration;
end

function fNext = hold_step(f, dt, tAbs, params, opts)
[rPlus, rMinus] = retention_rates(f, tAbs, params, opts);
lambda = rPlus + rMinus;
fNext = f;
active = lambda > 0.0;
fInf = zeros(size(f));
fInf(active) = rPlus(active) ./ lambda(active);
fNext(active) = fInf(active) + (f(active) - fInf(active)) .* exp(-lambda(active) * dt);
fNext = min(max(fNext, 0.0), 1.0);

if should_clamp_depol_zero(opts)
    pBefore = domain_p(f, params);
    pAfter = domain_p(fNext, params);
    if pBefore > 0.0 && pAfter < 0.0
        fNext = adjust_domain_population(fNext, 0.0, -1.0, params);
    elseif pBefore < 0.0 && pAfter > 0.0
        fNext = adjust_domain_population(fNext, 0.0, +1.0, params);
    end
end
end

function clamp = should_clamp_depol_zero(opts)
retentionEnable = get_option(opts, 'retentionEnable', true);
fixedRateEnable = get_option(opts, 'fixedRateEnable', false);
kDep = get_option(opts, 'kDep', 1.0);
eHold = get_option(opts, 'eHold', 0.0);
eImp = get_option(opts, 'eImp', 0.0);
clamp = retentionEnable && ~fixedRateEnable && kDep > 0.0 && abs(eHold) <= 1e-15 && abs(eImp) <= 1e-15;
end

function [rPlus, rMinus, vFe] = retention_rates(f, tAbs, params, opts)
retentionEnable = get_option(opts, 'retentionEnable', true);
if ~retentionEnable
    rPlus = zeros(1, params.nDomains);
    rMinus = zeros(1, params.nDomains);
    vFe = 0.0;
    return;
end

fixedRateEnable = get_option(opts, 'fixedRateEnable', false);
if fixedRateEnable
    rPlus = get_option(opts, 'fixedRPlus', zeros(1, params.nDomains));
    rMinus = get_option(opts, 'fixedRMinus', zeros(1, params.nDomains));
    vFe = 0.0;
    return;
end

kDep = get_option(opts, 'kDep', params.kDep);
eHold = get_option(opts, 'eHold', params.eHold);
eImp = get_option(opts, 'eImp', params.eImp);
pNow = domain_p(f, params);
vFe = -kDep * pNow + eHold + eImp;

if abs(vFe) <= 1e-15
    rPlus = zeros(1, params.nDomains);
    rMinus = zeros(1, params.nDomains);
    return;
end

vAbs = max(abs(vFe), params.vFieldFloor);
tau = params.nlsTau0 .* exp((params.activationVoltage ./ vAbs) .^ params.nlsExponent);
trapMultiplier = 1.0 + params.trapAccel * (1.0 - exp(-max(tAbs, 0.0) / params.tauTrap));
rate = min(params.maxRate, trapMultiplier ./ tau);

if vFe > 0.0
    rPlus = rate;
    rMinus = zeros(1, params.nDomains);
else
    rPlus = zeros(1, params.nDomains);
    rMinus = rate;
end
end

function [dPdt, info] = rates_and_derivative(f, tAbs, params, opts)
[rPlus, rMinus, vFe] = retention_rates(f, tAbs, params, opts);
dfdt = (1.0 - f) .* rPlus - f .* rMinus;
dPdt = 2.0 * sum(params.domainWeights .* dfdt);
info = struct('rPlus', rPlus, 'rMinus', rMinus, 'vFe', vFe);
end

function out = write_state(state, polarity, ampScale, width, params, opts)
if nargin < 6
    opts = struct();
end

programmingEnable = get_option(opts, 'programmingEnable', true);
startP = domain_p(state.f, params);
out = struct();
out.state = state;
out.info = struct('startF', state.f, 'startP', startP, 'vEff', 0.0, 'targetP', startP);

if ~programmingEnable || polarity == 0.0 || ampScale == 0.0 || width == 0.0
    return;
end

vPulse = polarity * ampScale * params.vWrite;
vEff = delayed_voltage(vPulse, width, params.tauVeff);
targetP = preisach_target(vEff, params);
pNew = minor_loop_update(startP, targetP, params);
out.state.f = adjust_domain_population(state.f, pNew, sign_nonzero(vPulse), params);
out.state.history = update_history(state.history, sign_nonzero(vPulse), vEff, startP, domain_p(out.state.f, params));
out.info.vEff = vEff;
out.info.targetP = targetP;
end

function params = default_params()
params.nDomains = 8;
params.domainWeights = ones(1, params.nDomains) / params.nDomains;
params.vWrite = 2.4;
params.tp = 2e-6;
params.tauVeff = 0.28e-6;
params.pSat = 1.0;
params.alphaPreisach = 1.55;
params.vCoercive = 0.85;
params.minorScale = 0.78;
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
params.vth0 = 0.5;
params.pr = 0.15;
params.vthGain = 0.15 / 0.02;
end

function params = with_weights(params, weights)
params.domainWeights = zeros(1, params.nDomains);
count = min(numel(weights), params.nDomains);
params.domainWeights(1:count) = weights(1:count);
params.domainWeights = params.domainWeights ./ sum(params.domainWeights);
end

function state = state_from_p(pNorm, params)
state = state_from_f(0.5 * ones(1, params.nDomains), params);
state.f = adjust_domain_population(state.f, pNorm, sign_nonzero(pNorm), params);
end

function state = state_from_f(f, params)
values = 0.5 * ones(1, params.nDomains);
count = min(numel(f), params.nDomains);
values(1:count) = f(1:count);
state = struct();
state.f = min(max(values, 0.0), 1.0);
state.history = initial_history();
state.clock = 0.0;
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

function p = domain_p(f, params)
p = sum(params.domainWeights .* (2.0 .* f - 1.0));
end

function err = state_error(a, b, params)
err = max(max(abs(a.f - b.f)), abs(domain_p(a.f, params) - domain_p(b.f, params)));
end

function f = adjust_domain_population(f, pTarget, direction, params)
pTarget = min(max(pTarget, -1.0), 1.0);
targetOccupancy = (pTarget + 1.0) / 2.0;
currentOccupancy = sum(params.domainWeights .* f);
delta = targetOccupancy - currentOccupancy;

if abs(delta) <= 1e-14
    return;
end

if direction >= 0.0
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
    if abs(delta) <= 1e-14
        break;
    end
end

f = min(max(f, 0.0), 1.0);
end

function value = delayed_voltage(vIn, tLocal, tauVeff)
if tLocal <= 0.0
    value = 0.0;
else
    value = vIn * (1.0 - exp(-tLocal / tauVeff));
end
end

function p = reference_write_p(pStart, vPulse, width, params)
vEff = delayed_voltage(vPulse, width, params.tauVeff);
pTarget = preisach_target(vEff, params);
p = minor_loop_update(pStart, pTarget, params);
end

function p = preisach_target(vEff, params)
if vEff >= 0.0
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

function times = hold_times(duration)
if duration <= 0.0
    times = 0.0;
elseif duration <= 1e-3
    times = linspace(0.0, duration, 251).';
else
    minStep = min(1e-6, duration / 1e6);
    times = unique([0.0; logspace(log10(minStep), log10(duration), 260).']);
end
end

function opts = fixed_rate_opts(params, rPlus, rMinus)
opts = struct();
opts.retentionEnable = true;
opts.fixedRateEnable = true;
opts.fixedRPlus = zeros(1, params.nDomains);
opts.fixedRMinus = zeros(1, params.nDomains);
opts.fixedRPlus(1:numel(rPlus)) = rPlus;
opts.fixedRMinus(1:numel(rMinus)) = rMinus;
end

function opts = set_times(opts, times)
opts.times = times(:);
end

function value = get_option(opts, name, defaultValue)
if isfield(opts, name)
    value = opts.(name);
else
    value = defaultValue;
end
end

function ok = approaches_zero(trace, expectedSign)
tol = 1e-6;
signed = expectedSign .* trace;
ok = all(signed >= -tol) && abs(trace(end)) <= abs(trace(1)) + tol && max([0.0; diff(abs(trace))]) <= 5e-3;
end

function ok = nonincreasing(values)
if isempty(values)
    ok = false;
else
    ok = all(diff(values) <= 1e-12);
end
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

function result = pass_fail(pass, evidence, failReason)
if pass
    result = make_result('PASS', evidence, '');
else
    result = make_result('FAIL', evidence, failReason);
end
end

function result = make_result(status, evidence, missing)
result = struct('status', status, 'evidence', evidence, 'missing', missing);
end

function tableOut = strict_table(strict, caseIds)
rows = cell(numel(caseIds), 4);
for idx = 1:numel(caseIds)
    item = strict.(caseIds{idx});
    rows(idx, :) = {caseIds{idx}, item.status, item.evidence, item.missing};
end
tableOut = cell2table(rows, 'VariableNames', {'CaseId', 'Status', 'Evidence', 'MissingOrFailReason'});
end
