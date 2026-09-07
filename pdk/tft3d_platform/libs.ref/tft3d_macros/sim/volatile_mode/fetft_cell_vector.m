function y = fetft_cell_vector(t)
%FETFT_CELL_VECTOR Evaluate the FeTFT DRAM-like dynamic-cell equations.
%
% Output order:
%   [phase; dP; p17; p18; dVQ; loopGain; polarizationGain;
%    senseMargin; vtShift; idProxy; refreshNeeded]
%
% NLS/detrapping retention mechanism adapted from:
% F. Mo et al., "Efficient Erase Operation by GIDL Current for 3D Structure
% FeFETs With Gate Stack Engineering and Compact Long-Term Retention Model,"
% IEEE Journal of the Electron Devices Society, vol. 10, pp. 115-122, 2022,
% doi: 10.1109/JEDS.2022.3142046.

tWrite = 2e-6;
tReadStart = 22e-6;
dP0 = 1.0;
tauWrite = 0.35e-6;
tauNls = 11e-6;
betaRetention = 0.62;
trapAccel = 0.18;
tauTrap = 25e-6;
pEq = 0.0;
aWrite = 0.25;
aHold = 0.35;
aRead = 0.88;
bWrite = 0.12;
bHold = 0.08;
bRead = 0.12;
vMin = 0.12;
kappa = 0.35;
gmProxy = 1.0;
gPProxy = 0.20;

dPWriteEnd = dP0 * (1.0 - exp(-tWrite / tauWrite));

if t < tWrite
    phase = 1.0;
    dP = dP0 * (1.0 - exp(-t / tauWrite));
    a = aWrite;
    b = bWrite;
elseif t < tReadStart
    phase = 2.0;
    tHold = t - tWrite;
    dP = dPWriteEnd * retention_factor(tHold, tauNls, betaRetention, trapAccel, tauTrap);
    a = aHold;
    b = bHold;
else
    phase = 3.0;
    tHold = t - tWrite;
    dP = dPWriteEnd * retention_factor(tHold, tauNls, betaRetention, trapAccel, tauTrap);
    a = aRead;
    b = bRead;
end

if a >= 1.0
    a = 0.999999;
end

p17 = pEq + 0.5 * dP;
p18 = pEq - 0.5 * dP;
loopGain = a;
polarizationGain = b / (1.0 - a);
dVQ = polarizationGain * dP;
senseMargin = abs(dVQ) - vMin;
vtShift = kappa * dP;
idProxy = gmProxy * dVQ + gPProxy * dP;
refreshNeeded = double(senseMargin < 0.0);

y = [phase; dP; p17; p18; dVQ; loopGain; polarizationGain; ...
     senseMargin; vtShift; idProxy; refreshNeeded];
end

function factor = retention_factor(tHold, tauNls, betaRetention, trapAccel, tauTrap)
% Effective reduction of the paper's NLS depolarization retention model.
% NLS depolarized fraction: 1 - exp(-(t/tau)^beta).
% Electron detrapping is represented as a gradual multiplier on the exponent.
if tHold <= 0
    factor = 1.0;
    return;
end

trapMultiplier = 1.0 + trapAccel * (1.0 - exp(-tHold / tauTrap));
factor = exp(-trapMultiplier * (tHold / tauNls) ^ betaRetention);
end
