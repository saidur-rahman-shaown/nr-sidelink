function [hData, noiseVar] = dmrsEstimate(rxDmrs, refDmrs, dmrsInd, dataInd, nSubcarriers)
%dmrsEstimate Channel estimate at the data REs, interpolated from the DM-RS, plus noise variance.
%Spec:   none. Channel estimation is where a vendor differentiates -- +phy/+rx/CLAUDE.md: "Not
%        specified anywhere. This is where our performance comes from."
%Inputs: rxDmrs        M-by-1 complex -- received DM-RS symbols, from gridExtract
%        refDmrs       M-by-1 complex -- the DM-RS the transmitter would have sent, regenerated
%                      locally from the same clause-8.4.1.1 generator
%        dmrsInd       M-by-2 integer [k l] -- their positions
%        dataInd       N-by-2 integer [k l] -- the positions to interpolate onto
%        nSubcarriers  integer -- grid height, for the interpolation domain
%Outputs: hData     N-by-1 complex -- the channel estimate at each data RE
%         noiseVar  real, >0 -- estimated noise variance per RE
%
%LEAST SQUARES PER DM-RS RE, THEN NEAREST-DM-RS-SYMBOL IN TIME, LINEAR IN FREQUENCY.
%------------------------------------------------------------------------------------
%Deliberately the simplest estimator that is not cheating: H_ls = rx / ref at each pilot, then
%interpolate. No MMSE, no Wiener filtering, no Doppler tracking. It is a real estimator with
%real estimation noise, which is the point -- a "perfect channel knowledge" receiver would
%produce BLER curves 1 to 2 dB optimistic and every downstream system-level result would
%inherit that bias with nothing to reveal it.
%
%The noise variance is estimated from the residual between neighbouring pilots in frequency
%rather than assumed known. A receiver handed the true noise variance is being told something
%the channel does not tell it, and the LLR scaling that depends on it is exactly where that
%unearned knowledge would show up as gain.

if numel(rxDmrs) ~= numel(refDmrs)
    error('rx:ce:dmrsEstimate:sizeMismatch', 'dmrsEstimate: received and reference DM-RS must be the same length');
end
if isempty(rxDmrs)
    error('rx:ce:dmrsEstimate:noPilots', 'dmrsEstimate: no DM-RS to estimate from');
end

hLs = rxDmrs(:) ./ refDmrs(:);

% Noise variance from the frequency-direction difference between adjacent pilots in the same
% symbol. Adjacent pilots see almost the same channel, so their difference is mostly noise;
% halving the mean square difference removes the doubling from differencing two noisy values.
dmrsSymbols = unique(dmrsInd(:, 2));
diffs = [];
for s = 1:numel(dmrsSymbols)
    inSym = dmrsInd(:, 2) == dmrsSymbols(s);
    h     = hLs(inSym);
    if numel(h) > 1
        diffs = [diffs; diff(h)]; %#ok<AGROW>
    end
end
if isempty(diffs)
    noiseVar = eps;
else
    noiseVar = max(mean(abs(diffs).^2) / 2, eps);
end

% Interpolate: for each data RE, take the DM-RS symbol nearest in time, then interpolate
% linearly across frequency within that symbol.
hData = complex(zeros(size(dataInd, 1), 1));
for s = 1:numel(dmrsSymbols)
    inSym  = dmrsInd(:, 2) == dmrsSymbols(s);
    kPilot = dmrsInd(inSym, 1);
    hPilot = hLs(inSym);
    [kPilot, order] = sort(kPilot);
    hPilot = hPilot(order);

    % Which data REs are closest in time to this DM-RS symbol.
    [~, nearest] = min(abs(double(dataInd(:, 2)) - double(dmrsSymbols(:))'), [], 2);
    mine = (nearest == s);
    if ~any(mine)
        continue;
    end
    kq = double(dataInd(mine, 1));
    if numel(kPilot) == 1
        hData(mine) = hPilot;
    else
        hData(mine) = interp1(double(kPilot), hPilot, kq, 'linear', 'extrap');
    end
end
end
