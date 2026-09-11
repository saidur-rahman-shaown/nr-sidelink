function r = syncSlot(snrDb, delaySamples, cfoHz, NID1, NID2, mu, stream)
%syncSlot One acquisition attempt: S-SSB through delay, frequency offset and noise, and back.
%Spec:   none itself -- it sequences the normative S-SSB chain (phy.chan.psbchTx) and the
%        non-normative acquisition modules (+phy/+rx/+sync/).
%Inputs: snrDb         real, dB -- Es/N0 relative to the S-SSB's own average sample power
%        delaySamples  integer, >=0 -- the timing offset the receiver must find
%        cfoHz         real -- the frequency offset it must estimate and correct
%        NID1          integer, 0..335
%        NID2          integer, 0 or 1
%        mu            integer, 0..3
%        stream        RandStream
%Outputs: r  scalar struct:
%   .timingOk   logical -- timing found within +/- 2 samples
%   .nid2Ok     logical -- N_ID,2 recovered from the S-PSS
%   .nid1Ok     logical -- N_ID,1 recovered from the S-SSS
%   .mibOk      logical -- MIB-SL recovered from the PSBCH, bit-exact
%   .acquired   logical -- all four, which is what "acquired" actually means
%   .timingErr  integer, samples
%   .cfoErrHz   real
%
%ACQUISITION IS A CHAIN, AND EVERY LINK CAN BREAK THE ONE AFTER IT
%-------------------------------------------------------------------
%Timing feeds the demodulator, N_ID,2 feeds the S-SSS search, and the composed N_ID^SL feeds
%both the PSBCH descrambling and its DM-RS. So a per-module test can pass on all four while the
%chain fails: an N_ID,2 error makes the S-SSS search look broken, and a timing error two
%samples out makes the PSBCH DM-RS estimate look like a bad channel. This function is the only
%place that failure mode is visible, which is why .acquired is the conjunction rather than any
%single flag.
%
%The frequency offset is estimated AFTER timing and corrected BEFORE demodulation, in that
%order, because cfoEstimate needs the two S-PSS symbols located and the demodulator needs the
%offset gone. Reversing them gives a frequency estimate taken over the wrong samples.

Nsymb = 13;
nSub  = 132;
NIDSL = NID1 + 336 * NID2;

% ---- transmit ------------------------------------------------------------
cfg = phy.ts38211.slPSBCHConfig(NIDSL, Nsymb);
blockGrid = complex(zeros(nSub, Nsymb));
mib = randi(stream, [0 1], 32, 1);
blockGrid = phy.chan.psbchTx(blockGrid, struct(), cfg, mib, NID1, NID2);
[wave, fs] = phy.lib.ofdmMod(blockGrid, mu, 0);

% ---- impair: delay, frequency offset, noise ------------------------------
t = (0:numel(wave) - 1)' / fs;
wave = wave .* exp(1j * 2 * pi * cfoHz * t);
tail = max(500, delaySamples);
rxw  = [complex(zeros(delaySamples, 1)); wave; complex(zeros(tail, 1))];

sigPow = mean(abs(wave).^2);
nVar   = sigPow / 10^(snrDb / 10);
rxw    = rxw + sqrt(nVar / 2) * (randn(stream, size(rxw)) + 1j * randn(stream, size(rxw)));

% ---- acquire -------------------------------------------------------------
searchLen = numel(rxw) - numel(wave) + 1;
[offset, nid2Hat] = phy.rx.sync.pssSearch(rxw, mu, nSub, searchLen);
r.timingErr = offset - delaySamples;
r.timingOk  = abs(r.timingErr) <= 2;
r.nid2Ok    = (nid2Hat == NID2);

% Align on the estimate, not on the truth: an acquisition that only works when handed the right
% timing is not an acquisition.
lo = offset + 1;
hi = min(lo + numel(wave) - 1, numel(rxw));
aligned = rxw(lo:hi);
if numel(aligned) < numel(wave)
    aligned = [aligned; complex(zeros(numel(wave) - numel(aligned), 1))];
end

cfoHat = phy.rx.sync.cfoEstimate(aligned, mu, nSub);
r.cfoErrHz = cfoHat - cfoHz;
tAlign  = (0:numel(aligned) - 1)' / fs;
aligned = aligned .* exp(-1j * 2 * pi * cfoHat * tAlign);

rxGrid = phy.lib.ofdmDemod(aligned, nSub, mu, 0);

[nid1Hat, nidslHat] = phy.rx.sync.sssDetect(rxGrid, nid2Hat);
r.nid1Ok = (nid1Hat == NID1);

% The PSBCH is descrambled with the RECOVERED identity, not the true one -- so an identity
% error shows up here as a decode failure, which is exactly how it would present on hardware.
cfgHat = phy.ts38211.slPSBCHConfig(nidslHat, Nsymb);
dataInd = phy.ts38211.slPSBCHIndices(Nsymb);
dmrsInd = phy.ts38211.slPSBCHDMRSIndices(Nsymb);
[dataSym, dmrsSym] = phy.rx.ce.gridExtract(rxGrid, dataInd, dmrsInd);
refDmrs = phy.ts38211.slPSBCHDMRS(nidslHat, Nsymb);
[hEst, nvEst] = phy.rx.ce.dmrsEstimate(dmrsSym, refDmrs, dmrsInd, dataInd, nSub);
[eqSym, eqNv] = phy.rx.eq.zfEqualise(dataSym, hEst, nvEst);
[mibHat, crcOk] = phy.chan.psbchRx(eqSym, struct(), cfgHat, eqNv, 8);

r.mibOk    = crcOk && isequal(logical(mibHat(:)), logical(mib(:)));
r.acquired = r.timingOk && r.nid2Ok && r.nid1Ok && r.mibOk;
end
