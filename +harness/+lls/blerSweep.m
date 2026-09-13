function tbl = blerSweep(mcsList, snrDbList, nAttempts, nTrials, LsubCH, scen, seed, ch, chLabel)
%blerSweep Measure BLER over MCS, SNR and retransmission index. Produces the PHY abstraction table.
%Spec:   none -- this is the measurement that replaces the placeholder curve in
%        harness.phyabs.blerLookup.
%Inputs: mcsList     1 x nMcs integer -- I_MCS values to measure
%        snrDbList   1 x nSnr real, dB -- Es/N0 grid, ascending
%        nAttempts   integer, >=1 -- retransmissions to measure, including the first
%        nTrials     integer, >=1 -- transport blocks per (MCS, SNR) point
%        LsubCH      integer, >=1 -- allocation width
%        scen        a scenario struct, so the link and system paths share one configuration
%        seed        integer -- reproduces the sweep exactly
%        ch          optional -- a fading channel from harness.chanmodel.tdlChannel, or [] for
%                    AWGN
%        chLabel     char -- the label written into .meta.channelModel. THE TABLE IS ONLY VALID
%                    FOR THIS CHANNEL, which is why harness.phyabs.blerLookup raises rather than
%                    substituting when asked for another one
%Outputs: tbl  scalar struct: .mcs .snrDb .attempt (the axes), .pssch and .pscch
%              (nMcs x nSnr x nAttempts and nMcs x nSnr BLER), .meta (what it was measured at)
%
%THE AXES ARE THE TABLE'S CONTRACT
%----------------------------------
%+harness/CLAUDE.md fixed the key structure before any curve existed -- MCS, SINR,
%retransmission index, channel model, speed -- precisely so that this function could be written
%later without changing harness.phyabs.blerLookup's signature or any of its callers. The two
%keys this sweep does not vary, channel model and speed, are recorded in .meta rather than
%omitted: a table that does not say what it was measured under invites being read as though it
%covered everything.
%
%PSCCH IS MEASURED IN THE SAME SLOTS AS PSSCH, NOT SEPARATELY
%--------------------------------------------------------------
%They share a slot, a channel realisation and a noise realisation, so measuring them together
%costs nothing and keeps their relationship honest. The system-level model decodes control at a
%lower effective MCS than data; this sweep is what says by how much, rather than the assumed
%offset the placeholder used.

nMcs = numel(mcsList);
nSnr = numel(snrDbList);
tbl.mcs     = mcsList(:)';
tbl.snrDb   = snrDbList(:)';
tbl.attempt = 1:nAttempts;
tbl.pssch   = zeros(nMcs, nSnr, nAttempts);
tbl.pscch   = zeros(nMcs, nSnr);

stream = RandStream('mt19937ar', 'Seed', seed);

if nargin < 8, ch = []; end
if nargin < 9
    if isempty(ch), chLabel = 'awgn'; else, chLabel = lower(strrep(ch.DelayProfile, '-', '')); end
end

for m = 1:nMcs
    lc = harness.lls.linkConfig(mcsList(m), LsubCH, scen);
    for s = 1:nSnr
        okAcc    = zeros(1, nAttempts);
        pscchAcc = 0;
        for t = 1:nTrials
            % One transport block across its attempts, plus the PSCCH of the first slot.
            first = harness.lls.linkSlot(lc, snrDbList(s), stream, 0, [], ch);
            pscchAcc = pscchAcc + first.pscchOk;
            okAcc = okAcc + harness.lls.linkHarq(lc, snrDbList(s), nAttempts, stream, ch);
        end
        tbl.pssch(m, s, :) = 1 - okAcc / nTrials;
        tbl.pscch(m, s)    = 1 - pscchAcc / nTrials;
    end
end

tbl.meta = struct( ...
    'channelModel', chLabel, ...
    'speedKmh', chSpeedKmh(ch, scen), 'delaySpreadNs', chDelaySpreadNs(ch), 'LsubCH', LsubCH, ...
    'listSize', 8, 'ldpcMaxIter', 12, 'equaliser', 'zf', ...
    'channelEstimation', 'dmrs-ls-linear', 'nTrials', nTrials, 'seed', seed, ...
    'mu', scen.mu, 'subchSizeRb', scen.subchSizeRb, 'slPsfchPeriod', scen.slPsfchPeriod, ...
    'generated', datestr(now, 'yyyy-mm-dd'));
end

% =========================================================================
function v = chSpeedKmh(ch, scen)
%chSpeedKmh The relative speed the channel was measured at, recovered from its Doppler.
if isempty(ch)
    v = 0;
else
    c = 299792458;
    v = ch.MaximumDopplerShift * c / scen.radio.fcHz * 3.6;
end
end

function v = chDelaySpreadNs(ch)
if isempty(ch), v = 0; else, v = ch.DelaySpread * 1e9; end
end
