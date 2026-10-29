function lk = linkCurves(opt)
%linkCurves Measure PSSCH BLER versus SNR for every MCS, over the real link-level chain.
%Spec:   none -- a measurement. The chain is +harness/+lls/ unchanged: the normative PSCCH/PSSCH
%        transmit chains, a real OFDM waveform through a TR 38.901 TDL channel, DM-RS channel
%        estimation, ZF equalisation, and HARQ soft combining over RV 0-2-3-1.
%Inputs: opt  optional struct, every field optional:
%          .mcs          I_MCS values to measure (default 0:27, the whole 64QAM table)
%          .focusMcs     MCS measured on a finer grid with more trials (default [5 6 11 27])
%          .LsubCH       allocation width in sub-channels (default 5: 50 PRB = a 20 MHz ITS
%                        channel at 30 kHz, the stored preconfiguration's BWP)
%          .nTrials / .focusTrials   transport blocks per point (default 40 / 80)
%          .stepDb / .focusStepDb    grid step through the waterfall (default 1 / 0.5 dB)
%          .nAttempts    HARQ transmissions per TB (default 3)
%          .refresh      true re-measures even when a cached result exists (default false)
%          .speedKmh     Doppler speed (default settings().radio.speedKmh = 120)
%          .nDmrs        PSSCH DM-RS symbols, 2..4 (default 2, the shipped table's pattern)
%          .tag          cache name suffix: linkCurves_<tag>.mat ('' -> linkCurves.mat)
%Outputs: lk  struct: .mcs (1 x nMcs), .curve{m} with fields .snrDb .bler (nSnr x nAttempts)
%             .trblklen .Qm .R .modScheme .nTrials, and .meta (channel, speed, width, receiver)
%
%WHY THIS EXISTS ALONGSIDE harness.phyabs.blerTable
%---------------------------------------------------
%The shipped table holds MCS {4 7 11 16 20}, and harness.phyabs.blerInterp answers any other MCS
%with the NEAREST row -- MCS 5 reads MCS 4's curve and MCS 27 reads MCS 20's, silently. The
%throughput and distance experiments need MCS 5, 6, 27 and the full range, so they are measured
%here rather than borrowed. The shipped table is not modified: the SLS-based experiments keep
%using it and restrict themselves to its MCS rows (experiments.private.assertTableMcs).
%
%TRIALS ARE INDEPENDENT CHANNEL REALISATIONS
%--------------------------------------------
%Each trial gets its own TDL object, seeded from (MCS, SNR, trial), so the trials of one point
%are independent draws of the fading process and the points are reproducible one by one -- which
%is also what lets them run under parfor. Within a trial the channel object is SHARED across the
%HARQ attempts (harness.lls.linkHarq), so a retransmission sees a channel correlated with the
%first attempt's at the configured Doppler, not a fresh one.
%
%THE GRID ADAPTS TO EACH MCS
%----------------------------
%A fixed grid would spend most of its points on SNRs where one MCS always fails or always
%succeeds. The scan starts about 10 dB below the AWGN Shannon point for the MCS's spectral
%efficiency, walks in 2 dB steps while even the third attempt always fails, then at the fine
%step through the waterfall, and stops once the FIRST attempt has decoded every trial at two
%consecutive points. If it reaches the ceiling first, the curve is reported as it stands: an
%error floor (Doppler-limited channel estimation at high order modulation) is a result, not a
%reason to extend the grid indefinitely.

if nargin < 1, opt = struct(); end
s = experiments.settings();
opt = withDefaults(opt, struct('mcs', 0:27, 'focusMcs', [5 6 11 27], 'LsubCH', 5, ...
    'nTrials', 40, 'focusTrials', 80, 'stepDb', 1, 'focusStepDb', 0.5, 'nAttempts', 3, ...
    'refresh', false, 'seed', 20261019, 'speedKmh', s.radio.speedKmh, 'nDmrs', 2, 'tag', ''));
if strcmp(s.scale, 'quick')
    opt.nTrials = 12; opt.focusTrials = 20; opt.stepDb = 2; opt.focusStepDb = 1;
end

name = 'linkCurves';
if ~isempty(opt.tag), name = [name '_' opt.tag]; end
cacheFile = fullfile(s.dataRoot, [name '.mat']);
if ~opt.refresh && isfile(cacheFile)
    c = load(cacheFile, 'lk');
    if all(ismember(opt.mcs, c.lk.mcs)) && isequal(c.lk.meta.LsubCH, opt.LsubCH) && ...
            strcmp(c.lk.meta.scale, s.scale)
        lk = c.lk;
        fprintf('linkCurves: using cached %s\n', cacheFile);
        return;
    end
end
if ~isfolder(s.dataRoot), mkdir(s.dataRoot); end

scen = harness.sls.scenarioInit(2, opt.seed, 'broadcast');
[~, fs] = phy.lib.ofdmMod(complex(zeros(opt.LsubCH * scen.subchSizeRb * 12, 14)), scen.mu, 0);
r = s.radio;
r.speedKmh = opt.speedKmh;
if s.useParallel && isempty(gcp('nocreate')), parpool('Processes', s.nWorkers); end

lk.mcs = opt.mcs;
lk.curve = cell(1, numel(opt.mcs));
t0 = tic;
for m = 1:numel(opt.mcs)
    mcs = opt.mcs(m);
    isFocus = ismember(mcs, opt.focusMcs);
    nT   = ifelse(isFocus, opt.focusTrials, opt.nTrials);
    step = ifelse(isFocus, opt.focusStepDb, opt.stepDb);
    lc = harness.lls.linkConfig(mcs, opt.LsubCH, scen, opt.nDmrs);
    se = lc.Qm * lc.R;
    snr = round(10 * log10(2^se - 1)) - 10;
    ceilDb = snr + 34;
    snrList = zeros(1, 0);
    bler = zeros(0, opt.nAttempts);
    pscch = zeros(0, 1);
    clean = 0;
    while snr <= ceilDb && clean < 2
        okMat = false(nT, opt.nAttempts); pcOk = false(nT, 1);
        seedBase = opt.seed + mcs * 1e6 + round((snr + 50) * 100) * 1e2;
        nA = opt.nAttempts;
        if s.useParallel
            parfor t = 1:nT
                [okMat(t, :), pcOk(t)] = oneTrial(lc, snr, nA, seedBase + t, r, fs);
            end
        else
            for t = 1:nT
                [okMat(t, :), pcOk(t)] = oneTrial(lc, snr, nA, seedBase + t, r, fs);
            end
        end
        b = 1 - mean(okMat, 1);
        snrList(end + 1) = snr; %#ok<AGROW>
        bler(end + 1, :) = b; %#ok<AGROW>
        pscch(end + 1, 1) = 1 - mean(pcOk); %#ok<AGROW>
        if b(1) == 0, clean = clean + 1; else, clean = 0; end
        % 2 dB strides while even the last attempt never decodes; the fine step once it starts to.
        if b(end) == 1, snr = snr + 2; else, snr = snr + step; end
    end
    lk.curve{m} = struct('snrDb', snrList, 'bler', bler, 'pscch', pscch, 'trblklen', lc.trblklen, ...
        'Qm', lc.Qm, 'R', lc.R, 'modScheme', lc.modScheme, 'nTrials', nT, 'NRB', lc.NRB);
    fprintf('linkCurves: MCS %2d (%s R=%.3f, TBS %d b) %d points %.1f..%.1f dB, floor BLER1 %.3f  [%.0f s]\n', ...
        mcs, lc.modScheme, lc.R, lc.trblklen, numel(snrList), snrList(1), snrList(end), ...
        bler(end, 1), toc(t0));
end
lk.meta = struct('channel', r.channel, 'speedKmh', r.speedKmh, 'delaySpreadNs', r.delaySpreadNs, ...
    'fcHz', r.fcHz, 'LsubCH', opt.LsubCH, 'NRB', opt.LsubCH * scen.subchSizeRb, ...
    'subchSizeRb', scen.subchSizeRb, 'slLengthSymbols', scen.slLengthSymbols, 'mu', scen.mu, ...
    'nDmrs', opt.nDmrs, 'dmrsSymbols', harness.lls.linkConfig(0, opt.LsubCH, scen, opt.nDmrs).dmrsSymbols, ...
    'nAttempts', opt.nAttempts, 'rvSequence', [0 2 3 1], 'receiver', 'DM-RS LS + linear interp, ZF, LDPC NMS 12 it', ...
    'focusMcs', opt.focusMcs, 'scale', s.scale, 'seed', opt.seed, 'generated', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')));
save(cacheFile, 'lk');
fprintf('linkCurves: saved %s (%.0f s)\n', cacheFile, toc(t0));
end

% =========================================================================
function [ok, pscchOk] = oneTrial(lc, snrDb, nAttempts, seed, r, fs)
%oneTrial One transport block over up to nAttempts transmissions, its own channel realisation.
stream = RandStream('mt19937ar', 'Seed', seed);
ch = harness.chanmodel.tdlChannel(r.channel, r.delaySpreadNs, r.speedKmh, r.fcHz, fs, seed);
[ok, pscchOk] = harness.lls.linkHarq(lc, snrDb, nAttempts, stream, ch);
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end

function o = withDefaults(o, d)
f = fieldnames(d);
for k = 1:numel(f)
    if ~isfield(o, f{k}), o.(f{k}) = d.(f{k}); end
end
end
