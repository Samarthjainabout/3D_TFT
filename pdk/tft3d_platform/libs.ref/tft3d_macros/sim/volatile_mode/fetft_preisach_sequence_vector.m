function y = fetft_preisach_sequence_vector(t)
%FETFT_PREISACH_SEQUENCE_VECTOR Evaluate write-hold-read sequence equations.
%
% Output order:
%   [phase; vProg17; vProg18; vEff17; vEff18; p17Preisach; p18Preisach;
%    dPProgrammed; retentionFactor; p17; p18; dP; polarizationGain;
%    dVQ; loopGain; senseMargin; refreshNeeded]
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

tWrite = 2e-6;
tReadStart = 22e-6;

vWrite = 2.4;
tauVeff = 0.28e-6;
pSat = 1.0;
alphaPreisach = 1.55;
vCoercive = 0.85;
minorScale = 0.78;

tauNls = 11e-6;
betaRetention = 0.62;
trapAccel = 0.18;
tauTrap = 25e-6;

aWrite = 0.25;
aHold = 0.35;
aRead = 0.88;
bWrite = 0.06;
bHold = 0.04;
bRead = 0.06;
vMin = 0.12;

vProg17 = vWrite;
vProg18 = -vWrite;

vEff17WriteEnd = delayed_voltage(vProg17, tWrite, tauVeff);
vEff18WriteEnd = delayed_voltage(vProg18, tWrite, tauVeff);
p17WriteEnd = minorScale * preisach_program_up(vEff17WriteEnd, pSat, alphaPreisach, vCoercive);
p18WriteEnd = minorScale * preisach_program_down(vEff18WriteEnd, pSat, alphaPreisach, vCoercive);
dPWriteEnd = p17WriteEnd - p18WriteEnd;

if t < tWrite
    phase = 1.0;
    vEff17 = delayed_voltage(vProg17, t, tauVeff);
    vEff18 = delayed_voltage(vProg18, t, tauVeff);
    p17Preisach = minorScale * preisach_program_up(vEff17, pSat, alphaPreisach, vCoercive);
    p18Preisach = minorScale * preisach_program_down(vEff18, pSat, alphaPreisach, vCoercive);
    dPProgrammed = p17Preisach - p18Preisach;
    retentionFactor = 1.0;
    p17 = p17Preisach;
    p18 = p18Preisach;
    a = aWrite;
    b = bWrite;
elseif t < tReadStart
    phase = 2.0;
    vEff17 = 0.0;
    vEff18 = 0.0;
    p17Preisach = p17WriteEnd;
    p18Preisach = p18WriteEnd;
    dPProgrammed = dPWriteEnd;
    retentionFactor = retention_factor(t - tWrite, tauNls, betaRetention, trapAccel, tauTrap);
    dP = dPProgrammed * retentionFactor;
    commonP = 0.5 * (p17WriteEnd + p18WriteEnd);
    p17 = commonP + 0.5 * dP;
    p18 = commonP - 0.5 * dP;
    a = aHold;
    b = bHold;
else
    phase = 3.0;
    vEff17 = 0.0;
    vEff18 = 0.0;
    p17Preisach = p17WriteEnd;
    p18Preisach = p18WriteEnd;
    dPProgrammed = dPWriteEnd;
    retentionFactor = retention_factor(t - tWrite, tauNls, betaRetention, trapAccel, tauTrap);
    dP = dPProgrammed * retentionFactor;
    commonP = 0.5 * (p17WriteEnd + p18WriteEnd);
    p17 = commonP + 0.5 * dP;
    p18 = commonP - 0.5 * dP;
    a = aRead;
    b = bRead;
end

if t < tWrite
    dP = p17 - p18;
end

if a >= 1.0
    a = 0.999999;
end

loopGain = a;
polarizationGain = b / (1.0 - a);
dVQ = polarizationGain * dP;
senseMargin = abs(dVQ) - vMin;
refreshNeeded = double(senseMargin < 0.0);

y = [phase; vProg17; vProg18; vEff17; vEff18; p17Preisach; p18Preisach; ...
     dPProgrammed; retentionFactor; p17; p18; dP; polarizationGain; ...
     dVQ; loopGain; senseMargin; refreshNeeded];
end

function value = delayed_voltage(vIn, tLocal, tauVeff)
if tLocal <= 0
    value = 0.0;
else
    value = vIn * (1.0 - exp(-tLocal / tauVeff));
end
end

function p = preisach_up(vEff, pSat, alphaPreisach, vCoercive)
p = pSat * tanh(alphaPreisach * (vEff - vCoercive));
end

function p = preisach_down(vEff, pSat, alphaPreisach, vCoercive)
p = pSat * tanh(alphaPreisach * (vEff + vCoercive));
end

function p = preisach_program_up(vEff, pSat, alphaPreisach, vCoercive)
% Normalize the upward Preisach branch so Veff=0 maps to zero programmed P.
p0 = preisach_up(0.0, pSat, alphaPreisach, vCoercive);
p = (preisach_up(vEff, pSat, alphaPreisach, vCoercive) - p0) / (pSat - p0);
end

function p = preisach_program_down(vEff, pSat, alphaPreisach, vCoercive)
% Normalize the downward Preisach branch so Veff=0 maps to zero programmed P.
p0 = preisach_down(0.0, pSat, alphaPreisach, vCoercive);
p = (preisach_down(vEff, pSat, alphaPreisach, vCoercive) - p0) / (pSat + p0);
end

function factor = retention_factor(tHold, tauNls, betaRetention, trapAccel, tauTrap)
if tHold <= 0
    factor = 1.0;
    return;
end

trapMultiplier = 1.0 + trapAccel * (1.0 - exp(-tHold / tauTrap));
factor = exp(-trapMultiplier * (tHold / tauNls) ^ betaRetention);
end
