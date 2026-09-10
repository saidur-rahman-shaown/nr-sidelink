function bler = blerLookup(mcs, sinrDb, txAttempt, channelModel, speedKmh)
%blerLookup Block error rate for one transport block, from the MEASURED link-level table.
%Spec:   none -- PHY abstraction, not a 3GPP quantity.
%Inputs: mcs           integer, 0..31 -- I_MCS
%        sinrDb        real array, dB -- post-equalisation SINR. NaN where the link is unheard
%        txAttempt     integer, >=1 -- 1 for the initial transmission, 2 for the first
%                      retransmission, and so on. The table's retransmission dimension carries
%                      real soft-combining gain measured with a soft buffer, not an assumed
%                      per-attempt dB bonus
%        channelModel  char -- must match what the table was measured under
%        speedKmh      real, >=0 -- likewise
%Outputs: bler  real array in [0,1], same size as sinrDb
%
%THIS IS NO LONGER A PLACEHOLDER
%--------------------------------
%Until Phase 3 this function was a logistic in SINR with an invented midpoint and slope, and
%every header that consumed it said so. It now reads harness.phyabs.blerTable -- BLER measured
%by +harness/+lls/ over the real transmit chains, a real OFDM waveform, DM-RS channel
%estimation and zero-forcing equalisation, with soft combining across redundancy versions.
%
%The SIGNATURE HAS NOT CHANGED, which was the point of fixing the key structure in Phase 0
%before any curve existed: no caller was touched to make this switch. +harness/CLAUDE.md's
%warning -- "Adding a dimension later means regenerating every curve, which is the most
%expensive avoidable mistake in this phase" -- is the reason all five keys were taken from the
%start even while three were ignored.
%
%The interpolation rule, the out-of-range behaviour and the reason for each are stated in
%harness.phyabs.blerInterp. In short: linear in SNR, nearest in MCS, clamped at every edge,
%never extrapolated.
%
%WHAT IS STILL AN APPROXIMATION
%-------------------------------
%The table is measured over AWGN at zero speed and one allocation width, so those keys are
%checked rather than interpolated: an unknown channel model or a nonzero speed is REJECTED, not
%silently answered with the AWGN curve. A fading table is the next measurement, not a
%reinterpretation of this one.

tbl = harness.phyabs.blerTable();

if ~(mcs >= 0 && mcs <= 31 && mod(mcs, 1) == 0)
    error('phyabs:blerLookup:badMcs', 'blerLookup: mcs must be an integer in 0..31, got %s', num2str(mcs));
end
if ~(txAttempt >= 1 && mod(txAttempt, 1) == 0)
    error('phyabs:blerLookup:badAttempt', 'blerLookup: txAttempt must be an integer >= 1, got %s', num2str(txAttempt));
end
if ~ischar(channelModel)
    error('phyabs:blerLookup:badModel', 'blerLookup: channelModel must be a char label');
end
if ~(speedKmh >= 0)
    error('phyabs:blerLookup:badSpeed', 'blerLookup: speedKmh must be >= 0, got %s', num2str(speedKmh));
end
% A key the table was not measured under is an error, never a substitution. Answering an
% unknown key with the nearest measured one is exactly the silent extrapolation this whole
% module is written to avoid.
if ~strcmp(channelModel, tbl.meta.channelModel)
    error('phyabs:blerLookup:unknownModel', 'blerLookup: the table was measured over ''%s'', not ''%s'' -- measure a new table rather than reading this one off-key', tbl.meta.channelModel, channelModel);
end
if speedKmh ~= tbl.meta.speedKmh
    error('phyabs:blerLookup:unknownSpeed', 'blerLookup: the table was measured at %g km/h, not %g', tbl.meta.speedKmh, speedKmh);
end

bler = harness.phyabs.blerInterp(tbl, 'pssch', mcs, sinrDb, txAttempt);
end
