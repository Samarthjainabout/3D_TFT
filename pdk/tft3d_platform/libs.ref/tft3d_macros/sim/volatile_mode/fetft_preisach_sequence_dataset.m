function sequenceInput = fetft_preisach_sequence_dataset(tStop, dt)
%FETFT_PREISACH_SEQUENCE_DATASET Build a time/value matrix for Simulink.
%
% The first column is time in seconds. The remaining columns match the
% output order of fetft_preisach_sequence_vector.m.

if nargin < 1
    tStop = 40e-6;
end

if nargin < 2
    dt = 5e-8;
end

time = (0:dt:tStop).';
values = zeros(numel(time), 17);

for idx = 1:numel(time)
    values(idx, :) = fetft_preisach_sequence_vector(time(idx)).';
end

sequenceInput = [time, values];
end
