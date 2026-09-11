function r = linkSlot(lc, snrDb, stream, rv, tbBits)
%linkSlot One link-level slot: build, modulate, impair, demodulate, estimate, equalise, decode.
%Spec:   none itself -- it sequences the normative chains and the non-normative receiver.
%Inputs: lc      from harness.lls.linkConfig
%        snrDb   real, dB -- Es/N0 per resource element
%        stream  RandStream -- the one source of randomness, so a sweep is reproducible
%        rv      integer, 0..3 -- redundancy version for this transmission
%        tbBits  trblklen-by-1, or [] -- the transport block. Passed in so a retransmission
%                carries the SAME block as the initial transmission; [] generates a fresh one
%Outputs: r  scalar struct: .pscchOk .pscchFalseAlarm .sci2Ok .psschOk, .dataLlr (the SL-SCH
%            LLRs) and .tbBits (the block that was sent), so a caller can soft-combine across
%            redundancy versions
%
%THE RECEIVER DOES NOT KNOW THE CHANNEL OR THE NOISE
%----------------------------------------------------
%The channel is estimated from the DM-RS and the noise variance from the pilot residual --
%neither is handed in. A "perfect channel knowledge" receiver produces curves 1 to 2 dB
%optimistic, and every system-level result built on those curves inherits the bias with nothing
%anywhere to reveal it. That is the single reason this path is slow enough to need a sweep
%rather than a formula.
%
%PSCCH AND PSSCH ARE DECODED INDEPENDENTLY, IN THE ORDER A REAL RECEIVER MUST
%-----------------------------------------------------------------------------
%PSCCH first, because its payload is what tells a receiver the PSSCH's MCS, allocation and
%SCI-2 size. Here those are known from lc, so the ordering is not load-bearing for correctness
%-- but the two block-error outcomes are reported separately because the system-level model
%needs both curves, and because a slot where control decodes and data does not is the case that
%produces a NACK rather than a DTX.

nSub = lc.NRB * 12;
grid = complex(zeros(nSub, lc.NsymbSlot));

% ---- transmit ------------------------------------------------------------
sci1aBits = randi(stream, [0 1], lc.sci1aBitLen, 1);
sci2Bits  = randi(stream, [0 1], lc.sci2BitLen, 1);
if isempty(tbBits)
    tbBits = randi(stream, [0 1], lc.trblklen, 1);
end

[grid, pscchInfo] = phy.chan.pscchTx(grid, lc.carrier, lc.pscchCfg, sci1aBits);
txp = struct('Gsci2', lc.Gsci2, 'R', lc.R, 'rv', rv, 'Qm', lc.Qm, ...
    'modScheme', lc.modScheme, 'nlayers', 1);
[grid, psschInfo] = phy.chan.psschTx(grid, lc.carrier, lc.psschCfg, lc.mapCfg, ...
    sci2Bits, tbBits, txp);

% ---- OFDM, then the channel ---------------------------------------------
[waveform, ~] = phy.lib.ofdmMod(grid, lc.mu, lc.nsf);

% Es/N0 per RE. The noise is added in the TIME domain, at the amplitude
% harness.lls.noiseScale measured as giving unit per-RE variance, then scaled to the target.
nVarTarget = 10^(-snrDb / 10);
amp = lc.noiseScale * sqrt(nVarTarget);
noise = amp * (randn(stream, numel(waveform), 1) + 1j * randn(stream, numel(waveform), 1)) / sqrt(2);
rxWave = waveform + noise;

rxGrid = phy.lib.ofdmDemod(rxWave, nSub, lc.mu, lc.nsf);

% ---- PSCCH: BLIND SEARCH across candidate sub-channel starts -------------
% The receiver is not told where the PSCCH is. phy.rx.det.pscchSearch tries every sub-channel
% start, estimating and equalising each candidate from its own DM-RS, because clause 8.1.2.2
% puts the PSCCH in the lowest sub-channel of an allocation the receiver does not yet know.
% Extracting at the transmitter's own indices -- which this function did until the detector
% existed -- is genie-aided and makes the control channel look more robust than it is.
nSubchInGrid = lc.NRB / scenSubchSize(lc);
[foundAt, ~, startsAt] = phy.rx.det.pscchSearch(rxGrid, lc.carrier, lc.pscchCfg, ...
    nSubchInGrid, scenSubchSize(lc), lc.sci1aBitLen, 0, 8);
% The transmitter placed its PSCCH at sub-channel 0 of this allocation, so a correct detection
% is one found there. A detection anywhere else is a FALSE ALARM and is counted as such rather
% than quietly accepted as success.
pscchOk    = any(foundAt & startsAt == 0);
pscchFalse = nnz(foundAt & startsAt ~= 0);

% ---- PSSCH ---------------------------------------------------------------
[psschData, psschDmrs] = phy.rx.ce.gridExtract(rxGrid, psschInfo.dataInd, psschInfo.dmrsInd);
refPsschDmrs = localPsschDmrs(lc, psschInfo);
[hS, nvS] = phy.rx.ce.dmrsEstimate(psschDmrs, refPsschDmrs, psschInfo.dmrsInd, ...
    psschInfo.dataInd, nSub);
[eqS, eqNvS] = phy.rx.eq.zfEqualise(psschData, hS, nvS);

rxp = struct('R', lc.R, 'rv', rv, 'modScheme', lc.modScheme, 'nlayers', 1, ...
    'trblklen', lc.trblklen, 'noiseVar', eqNvS, 'listSize', 8, 'maxIter', 12);
[~, sci2Ok, tbRx, psschOk] = phy.chan.psschRx(eqS, lc.carrier, lc.psschCfg, ...
    psschInfo, lc.sci2BitLen, rxp);

% The SL-SCH portion's LLRs, for a caller that wants to combine redundancy versions. Recovered
% the same way psschRx does internally rather than returned from inside it, so psschRx stays a
% pure normative inverse with no side channel.
r = struct('pscchOk', pscchOk, 'pscchFalseAlarm', pscchFalse, 'sci2Ok', sci2Ok, ...
    'psschOk', psschOk && isequal(logical(tbRx(:)), logical(tbBits(:))), ...
    'dataLlr', dataLlrFor(eqS, psschInfo, lc, eqNvS), 'tbBits', tbBits);
end

% =========================================================================
function llr = dataLlrFor(eqSym, info, lc, eqNv)
%dataLlrFor The SL-SCH portion's descrambled LLRs, in the same convention psschRx produces.
Msymb1 = info.Msymb1;
if isscalar(eqNv)
    nvS = eqNv; nvD = eqNv;
else
    nvS = eqNv(1:Msymb1); nvD = eqNv(Msymb1 + 1:end);
end
llrAll = [phy.lib.demodLLR(eqSym(1:Msymb1), 'QPSK', nvS); ...
          phy.lib.demodLLR(eqSym(Msymb1 + 1:end), lc.modScheme, nvD)];
c   = phy.lib.goldSeq(2^15 * lc.psschCfg.NID + 1010, numel(llrAll));
seq = [c(1:info.Gsci2); c(1:numel(llrAll) - info.Gsci2)];
llrAll = llrAll .* (1 - 2 * double(seq));
llr = llrAll(info.Gsci2 + 1:end);
end

% =========================================================================
function n = scenSubchSize(lc)
%scenSubchSize Sub-channel size in PRBs, recovered from the link config.
%The link allocation is LsubCH sub-channels wide, so the size is NRB/LsubCH. Derived rather
%than passed so linkConfig stays the single place the pool geometry is stated.
n = lc.NRB / lc.LsubCH;
end

% =========================================================================
function ref = localPsschDmrs(lc, info)
%localPsschDmrs Regenerate the PSSCH DM-RS the transmitter would have sent.
nPerSym = 6 * lc.mapCfg.NRB;
ref = complex(zeros(nPerSym * numel(lc.mapCfg.dmrsSymbols), 1));
for s = 1:numel(lc.mapCfg.dmrsSymbols)
    l = lc.mapCfg.dmrsSymbols(s);
    ref((s - 1) * nPerSym + (1:nPerSym)) = phy.ts38211.slPSSCHDMRS( ...
        lc.psschCfg.NID, l, lc.psschCfg.nsf, lc.psschCfg.NsymbSlot, nPerSym);
end
end
