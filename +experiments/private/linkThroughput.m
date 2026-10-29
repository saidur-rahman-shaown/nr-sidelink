function [T, prr, nTx] = linkThroughput(curve, snrDb, mode, slotMs, tbsBits)
%linkThroughput Link throughput and reliability from a measured BLER curve, per HARQ mode.
%Inputs: curve    one experiments.linkCurves curve (.snrDb, .bler nSnr x nAttempts, .trblklen)
%        snrDb    query SNRs (per RE)
%        mode     'none'     one transmission per TB
%                 'blind1'   two transmissions per TB, always (Mode-2 broadcast, 1 blind retx)
%                 'feedback' up to nAttempts, stopping at the first ACK (unicast PSFCH HARQ)
%        slotMs   slot duration
%        tbsBits  optional TBS to credit per success (e.g. the smaller PSFCH-pool TBS for
%                 'feedback'); default curve.trblklen
%Outputs: T    Mbit/s if the link transmits in every slot (full buffer, one UE)
%         prr  probability the TB is decoded within the mode's transmissions
%         nTx  mean transmissions spent per TB
%BLER is interpolated linearly in SNR; below the measured range it is the first measured value
%(1), above the last it is the last measured value -- so an error floor stays a floor rather
%than being extrapolated to zero.
if nargin < 5 || isempty(tbsBits), tbsBits = curve.trblklen; end
b = zeros(numel(snrDb), size(curve.bler, 2));
for a = 1:size(curve.bler, 2)
    b(:, a) = interp1(curve.snrDb, curve.bler(:, a), snrDb(:), 'linear', NaN);
    b(snrDb(:) < curve.snrDb(1), a) = curve.bler(1, a);
    b(snrDb(:) > curve.snrDb(end), a) = curve.bler(end, a);
end
switch mode
    case 'none'
        prr = 1 - b(:, 1); nTx = ones(size(prr));
    case 'blind1'
        prr = 1 - b(:, 2); nTx = 2 * ones(size(prr));
    case 'feedback'
        A = size(b, 2);
        prr = 1 - b(:, A);
        nTx = 1 + sum(b(:, 1:A - 1), 2);        % attempt a+1 happens iff attempts 1..a failed
    otherwise
        error('experiments:linkThroughput:mode', 'unknown mode %s', mode);
end
T = tbsBits .* prr ./ (nTx * slotMs * 1e-3) / 1e6;
T = reshape(T, size(snrDb)); prr = reshape(prr, size(snrDb)); nTx = reshape(nTx, size(snrDb));
end
