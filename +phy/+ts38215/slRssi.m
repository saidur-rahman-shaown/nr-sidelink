function [rssiW, rssiDbm, nRe] = slRssi(grid, prbStart, prbCount, slotSymbols)
%slRssi Sidelink received signal strength indicator (SL RSSI) for one sub-channel in one slot.
%Spec:   TS 38.215 V16.7.0, clause 5.1.25: "Sidelink Received Signal Strength Indicator (SL
%        RSSI) is defined as the linear average of the total received power (in [W]) observed in
%        the configured sub-channel in OFDM symbols of a slot configured for PSCCH and PSSCH,
%        starting from the 2nd OFDM symbol."
%Inputs: grid         K x L x P complex array -- the received sidelink resource grid, same
%                     [K x L x P] convention as slRsrp (+phy/+ts38211/CLAUDE.md). Unlike RSRP
%                     this is TOTAL received power, so every RE in the sub-channel counts, not
%                     just reference-signal REs -- noise and interference included, which is the
%                     entire point of the measurement.
%        prbStart     integer, >=0 -- first PRB of the sub-channel being measured, from
%                     +phy/+ts38214/subchannelMap's prbStart output. "The configured
%                     sub-channel" is a resource-pool construct owned by TS 38.214 clause 8;
%                     this function takes its PRB extent as given and never re-derives it.
%        prbCount     integer, >=1 -- sl-SubchannelSize, PRBs per sub-channel
%        slotSymbols  row vector of integer OFDM symbol indices, 0-BASED, ascending -- ALL
%                     symbols of the slot that are configured for PSCCH and PSSCH, INCLUDING
%                     the first one. Do not pre-strip the AGC symbol: see the note below.
%Outputs: rssiW    real, >=0, W -- the TOTAL received power over the sub-channel's prbCount*12
%                  subcarriers in one OFDM symbol, linearly averaged over the measured symbols; NaN
%                  when absent. Range: thermal floor over one sub-channel (about -110 dBm at 10 PRB,
%                  30 kHz, NF 9 dB) up to the receiver's input limit (about -20 dBm)
%         rssiDbm  real, dBm -- 10*log10(rssiW) + 30, or NaN when absent. Returned for the same
%                  reason slRsrp returns it: the sl-ThreshS-RSSI-CBR threshold this feeds
%                  (clause 5.1.27, via cbr) is configured in dBm, so a caller comparing in the
%                  wrong unit would silently classify every sub-channel the same way.
%         nRe      nonnegative integer -- resource elements averaged over, PER PORT
%                  (prbCount*12 * the number of measured symbols). nRe=0 means the measurement
%                  is ABSENT, not zero, and both values are NaN -- this package's interface
%                  rule, and the case that arises when slotSymbols has a single entry (the AGC
%                  symbol alone, which the clause excludes, leaving nothing to average).
%
%TOTAL OVER THE SUB-CHANNEL, AVERAGED OVER SYMBOLS -- NOT A PER-RE AVERAGE
%-------------------------------------------------------------------------
%Clause 5.1.25 is worded exactly as NR carrier RSSI in clause 5.1.3: "the linear average of the
%total received power (in [W]) observed only in certain OFDM symbols [...], in the measurement
%bandwidth, over N number of resource blocks". Clause 5.1.3 fixes what that phrase means, because
%SS-RSRQ = N x SS-RSRP / NR carrier RSSI: RSRP is per RE (clause 5.1.1), so RSSI must be the power
%of all N resource blocks together, or the ratio would not be dimensionless. "Total received
%power observed in the configured sub-channel" is therefore the sum over the sub-channel's REs in
%a symbol, and the "linear average" runs over the symbols. This function averaged per RE until
%2026-10-28, which read 10*log10(12*prbCount) low (-20.8 dB at 10 PRB) against
%sl-ThreshS-RSSI-CBR, so a busy sub-channel needed 20.8 dB more power to count as busy.
%
%"Starting from the 2nd OFDM symbol" is applied HERE, exactly once. +phy/CLAUDE.md requires
%naming which side applies a once-only transform, so: this function drops slotSymbols(1) and the
%caller MUST NOT. The dropped symbol is the AGC symbol, which by construction (see +phy/
%CLAUDE.md's slot assembly order -- "the AGC symbol duplicates the symbol after it") carries a
%copy of the next symbol rather than an independent observation, and whose received level is
%meaningless while the receiver's gain is still settling. A caller that strips it first and then
%calls this function measures one symbol too few, biasing every CBR built on top; a caller that
%passes only PSSCH symbols having already removed PSCCH ones is measuring the wrong thing
%entirely, since the clause says "configured for PSCCH and PSSCH".
%
%Antenna ports: clause 5.1.25 states no port summation (unlike clause 5.1.23's PSSCH-RSRP), and
%its receiver-diversity sentence ("the reported SL RSSI value shall not be lower than the
%corresponding SL RSSI of any of the individual receiver branches") is a LOWER BOUND on a UE
%combining branches, not a combining formula. Summing branches would violate that bound's
%intent by inflating RSSI with the antenna count, and averaging them would violate the bound
%outright whenever branches differ. Since the spec supplies a bound and no formula, this
%function refuses to guess: a multi-port grid is rejected, and branch combining belongs to
%whatever produced the grid. See slRsrp's header for the same distinction stated at length.
if prbStart < 0 || mod(prbStart, 1) ~= 0
    error('ts38215:slRssi:badPrbStart', 'slRssi: prbStart must be a nonnegative integer, got %s', num2str(prbStart));
end
if prbCount < 1 || mod(prbCount, 1) ~= 0
    error('ts38215:slRssi:badPrbCount', 'slRssi: prbCount must be a positive integer (sl-SubchannelSize), got %s', num2str(prbCount));
end
if ndims(grid) > 3
    error('ts38215:slRssi:badGrid', 'slRssi: grid must be a K x L x P array, got %d dimensions', ndims(grid));
end
[K, L, P] = size(grid);
if P > 1
    error('ts38215:slRssi:badPorts', 'slRssi: clause 5.1.25 defines no antenna-port summation, so SL RSSI is measured per receiver branch; got a grid with P=%d', P);
end
if isempty(slotSymbols)
    error('ts38215:slRssi:badSymbols', 'slRssi: slotSymbols must name the slot''s PSCCH/PSSCH symbols (including the first); an empty list is a caller error, not an absent measurement');
end
if ~isvector(slotSymbols) || any(mod(slotSymbols, 1) ~= 0) || any(slotSymbols < 0)
    error('ts38215:slRssi:badSymbols', 'slRssi: slotSymbols must be a vector of nonnegative integer 0-based symbol indices');
end
if any(diff(slotSymbols) <= 0)
    error('ts38215:slRssi:badSymbols', 'slRssi: slotSymbols must be strictly ascending so that "the 2nd OFDM symbol" is unambiguous');
end

NscRB = 12;   % TS 38.211 clause 4.4.4.1, N_sc^RB -- fixed, not a config field
kFirst = prbStart * NscRB;
kLast = kFirst + prbCount * NscRB - 1;
if kLast >= K
    error('ts38215:slRssi:subchannelOutOfGrid', 'slRssi: sub-channel PRBs %d..%d need subcarriers up to k=%d but the grid has only K=%d', prbStart, prbStart + prbCount - 1, kLast, K);
end
if any(slotSymbols >= L)
    error('ts38215:slRssi:symbolOutOfGrid', 'slRssi: slotSymbols addresses symbol l=%d but the grid has only L=%d', max(slotSymbols), L);
end

% Clause 5.1.25: "starting from the 2nd OFDM symbol" -- drop the first configured symbol.
measuredSymbols = slotSymbols(2:end);
if isempty(measuredSymbols)
    rssiW = NaN;
    rssiDbm = NaN;
    nRe = 0;
    return;
end

% Clause 5.1.25 (read with 5.1.3's NR carrier RSSI): the total received power over the
% sub-channel in each symbol, linearly averaged over those symbols.
total = 0;
nRe = 0;
for li = 1:numel(measuredSymbols)
    l = measuredSymbols(li);
    for k = kFirst:kLast
        re = grid(k + 1, l + 1);
        total = total + real(re)^2 + imag(re)^2;   % |re|^2, the RE's power contribution in W
        nRe = nRe + 1;
    end
end
rssiW = total / numel(measuredSymbols);
rssiDbm = 10 * log10(rssiW) + 30;
end
