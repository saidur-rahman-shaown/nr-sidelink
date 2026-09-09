function bler = blerLookup(mcs, sinrDb, txAttempt, channelModel, speedKmh)
%blerLookup Block error rate for one transport block. A PLACEHOLDER curve, keyed for the real one.
%Spec:   none -- PHY abstraction, not a 3GPP quantity.
%Inputs: mcs           integer, 0..31 -- I_MCS
%        sinrDb        real array, dB -- post-equalisation SINR
%        txAttempt     integer, >=1 -- 1 for the initial transmission, 2 for the first
%                      retransmission, and so on. Present because chase combining makes the
%                      n-th attempt's effective SINR higher than its instantaneous one
%        channelModel  char -- 'awgn', or a TDL/CDL label once those exist
%        speedKmh      real, >=0 -- relative speed; sets Doppler and therefore channel
%                      estimation loss
%Outputs: bler  real array in [0,1], same size as sinrDb
%
%THE KEY STRUCTURE IS THE POINT OF THIS FUNCTION, NOT THE CURVE
%---------------------------------------------------------------
%+harness/CLAUDE.md is emphatic: "Design the table's key structure at B5, before generating
%anything ... Adding a dimension later means regenerating every curve, which is the most
%expensive avoidable mistake in this phase." So the interface takes all five keys NOW --
%mcs, SINR, retransmission index, channel model and speed -- even though the placeholder body
%below reads only the first three. When the link-level simulator produces real curves in
%Phase 3, this signature does not change and no caller is touched.
%
%THE PLACEHOLDER, STATED PLAINLY
%--------------------------------
%A logistic in SINR whose midpoint rises with MCS and whose slope is fixed. It has the right
%shape (monotone, saturating at both ends) and roughly the right spacing between MCS levels,
%and it is otherwise invented. It is NOT calibrated against anything.
%  - Comparisons between policies on the same curve are meaningful.
%  - Absolute BLER, throughput and PRR-versus-distance numbers are NOT, until Phase 3 replaces
%    this with curves measured from +phy/+chan/ and +phy/+rx/.
%Chase combining is modelled as a 3 dB effective SINR gain per prior attempt, which is the
%ideal-combining bound and therefore optimistic.
%
%Out-of-range behaviour is stated rather than left to an extrapolation: the logistic saturates,
%so SINR far below the midpoint gives BLER 1 and far above gives 0. A real table must declare
%the same thing explicitly -- silently extrapolating off the end of a BLER table is how an SLS
%produces confident nonsense.

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
if ~strcmp(channelModel, 'awgn')
    error('phyabs:blerLookup:unknownModel', 'blerLookup: only ''awgn'' exists so far, got ''%s'' -- a real table must reject an unknown key rather than substitute one', channelModel);
end

% Midpoint of the waterfall, dB. -4 dB at MCS 0 rising ~0.9 dB per MCS index: the shape of a
% real family of curves, the numbers invented.
mcs0MidpointDb   = -4;
midpointPerMcsDb = 0.9;
slopePerDb       = 1.6;                 % logistic steepness; a real waterfall is steeper
combiningGainDb  = 3;                   % per prior attempt, the ideal chase-combining bound

midpoint  = mcs0MidpointDb + midpointPerMcsDb * mcs;
effective = sinrDb + combiningGainDb * (txAttempt - 1);
bler      = 1 ./ (1 + exp(slopePerDb * (effective - midpoint)));
bler(isnan(sinrDb)) = 1;                % a link that cannot be heard never decodes
end
