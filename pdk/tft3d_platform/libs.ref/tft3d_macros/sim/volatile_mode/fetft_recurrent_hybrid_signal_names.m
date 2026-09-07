function signals = fetft_recurrent_hybrid_signal_names()
%FETFT_RECURRENT_HYBRID_SIGNAL_NAMES Output order for recurrent hybrid data.

baseSignals = { ...
    'phase', 'writeCommand', 'vEff17', 'vEff18', ...
    'pStart17', 'pStart18', 'pTarget17', 'pTarget18', ...
    'p17Preisach', 'p18Preisach', 'p17', 'p18', ...
    'dPProgrammed', 'retentionFactor', 'dP', ...
    'loopGain', 'polarizationGain', 'dVQ', 'senseMargin', 'refreshNeeded'};

domainSignals = {};
for idx = 1:8
    domainSignals{end + 1} = sprintf('f17_%d', idx); %#ok<AGROW>
end
for idx = 1:8
    domainSignals{end + 1} = sprintf('f18_%d', idx); %#ok<AGROW>
end
for idx = 1:8
    domainSignals{end + 1} = sprintf('rPlus17_%d', idx); %#ok<AGROW>
end
for idx = 1:8
    domainSignals{end + 1} = sprintf('rMinus17_%d', idx); %#ok<AGROW>
end
for idx = 1:8
    domainSignals{end + 1} = sprintf('rPlus18_%d', idx); %#ok<AGROW>
end
for idx = 1:8
    domainSignals{end + 1} = sprintf('rMinus18_%d', idx); %#ok<AGROW>
end

fieldSignals = { ...
    'vFe17', 'vFe18', 'eDep17', 'eDep18', ...
    'eHold17', 'eHold18', 'eImp17', 'eImp18'};

historySignals = { ...
    'history17Branch', 'history18Branch', ...
    'history17TurnV', 'history18TurnV', ...
    'history17TurnP', 'history18TurnP', ...
    'history17Depth', 'history18Depth'};

controlSignals = {'programmingEnable', 'retentionEnable'};

signals = [baseSignals, domainSignals, fieldSignals, historySignals, controlSignals];
end
