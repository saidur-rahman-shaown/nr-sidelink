function [cbrRatio, nBusy, nSamples] = cbr(rssiDbmPerSubchannelSlot, threshSRssiCbrDbm)
%cbr Sidelink channel busy ratio (SL CBR).
%Spec:   TS 38.215 V16.7.0, clause 5.1.27: "SL Channel Busy Ratio (SL CBR) measured in slot n is
%        defined as the portion of sub-channels in the resource pool whose SL RSSI measured by
%        the UE exceed a (pre-)configured threshold provided by the higher layer parameter
%        sl-ThreshS-RSSI-CBR sensed over a CBR measurement window [n-a, n-1], wherein a is equal
%        to 100 or 100*2^mu slots, according to higher layer parameter sl-TimeWindowSizeCBR."
%        NOTE 1: "The slot index is based on physical slot index."
%Inputs: rssiDbmPerSubchannelSlot  nSlots x nSubchannels real matrix, dBm -- the SL RSSI
%                                  (clause 5.1.25, i.e. slRssi's rssiDbm output) of every
%                                  sub-channel of the resource pool, in every slot of the CBR
%                                  measurement window [n-a, n-1]. Row 1 is slot n-a and row
%                                  nSlots is slot n-1; slot n itself is NOT part of the window
%                                  and must not be passed. nSlots should be a from
%                                  cbrWindowSlots, but that is not enforced here -- this
%                                  function measures whatever window it is handed, and a caller
%                                  building the wrong-length window is a caller bug the
%                                  measurement cannot detect.
%                                  NaN marks a (slot, sub-channel) the UE did not measure --
%                                  a half-duplex own-transmission slot being the usual reason
%                                  (+phy/CLAUDE.md: "A slot the UE transmits in is a slot it did
%                                  not sense"). NaN entries are EXCLUDED FROM BOTH the numerator
%                                  and the denominator, so an unmeasured sub-channel neither
%                                  counts as busy nor dilutes the ratio toward idle.
%        threshSRssiCbrDbm         real, dBm -- sl-ThreshS-RSSI-CBR, ALREADY RESOLVED from the
%                                  raw INTEGER(0..45) to dBm by the caller. TS 38.331 V16.22.0:
%                                  "Value 0 corresponds to -112 dBm, value 1 to -110 dBm, value
%                                  n to (-112 + n*2) dBm", so the resolved range is -112..-22
%                                  dBm. +cfg/resourcePool.m stores the raw index and does not
%                                  resolve it, so this follows the same "pre-resolved units
%                                  taken as an input" pattern +phy/+ts38214/ uses for
%                                  sl-Thres-RSRP-List.
%Outputs: cbrRatio  real in [0,1], or NaN when absent -- the portion of measured
%                   (slot, sub-channel) samples whose SL RSSI EXCEEDS the threshold. This is
%                   the value TS 38.214 clause 8.1.6 feeds to cbrRangeIndex, and TS 38.331
%                   quantises to multiples of 0.01 (SL-CBR-r16, INTEGER(0..100)).
%         nBusy     nonnegative integer -- samples strictly above the threshold (the numerator)
%         nSamples  nonnegative integer -- measured samples, NaNs excluded (the denominator).
%                   nSamples=0 means the measurement is ABSENT, not zero, and cbrRatio is NaN:
%                   this package's interface rule again, and the case a UE hits at boot before
%                   its first full CBR window has elapsed. A caller must not read "CBR = 0"
%                   (an idle channel, transmit freely) out of "CBR unknown".
%
%"Exceed" is read as STRICTLY greater than the threshold, matching the clause's own word. An
%SL RSSI landing exactly on sl-ThreshS-RSSI-CBR therefore does NOT count as busy. Both the
%threshold and the measurements are compared in dBm; comparing one side in W would still produce
%a number in [0,1] and would still look like a plausible CBR, which is why slRssi returns dBm
%explicitly rather than leaving the conversion to each call site.
%
%Per-priority CBR is not a thing: unlike SL CR (clause 5.1.26 NOTE 5, "SL CR can be computed per
%priority level"), CBR is a property of the channel, not of the UE's own traffic, so there is
%one CBR per slot regardless of how many priorities the UE is transmitting at.
if ~isreal(threshSRssiCbrDbm) || ~isscalar(threshSRssiCbrDbm)
    error('ts38215:cbr:badThreshold', 'cbr: threshSRssiCbrDbm must be a real scalar in dBm (sl-ThreshS-RSSI-CBR resolved as -112 + n*2)');
end
if ~ismatrix(rssiDbmPerSubchannelSlot)
    error('ts38215:cbr:badRssi', 'cbr: rssiDbmPerSubchannelSlot must be an nSlots x nSubchannels matrix, got %d dimensions', ndims(rssiDbmPerSubchannelSlot));
end
if ~isreal(rssiDbmPerSubchannelSlot)
    error('ts38215:cbr:badRssi', 'cbr: rssiDbmPerSubchannelSlot must be real (dBm), not complex -- pass slRssi''s rssiDbm output, not its grid');
end

% Clause 5.1.27: count the measured sub-channel/slot samples, and how many exceed the threshold.
measured = ~isnan(rssiDbmPerSubchannelSlot);
nSamples = sum(measured(:));
if nSamples == 0
    cbrRatio = NaN;
    nBusy = 0;
    return;
end
nBusy = sum(rssiDbmPerSubchannelSlot(measured) > threshSRssiCbrDbm);
cbrRatio = nBusy / nSamples;
end
