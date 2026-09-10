function N = polarMotherLength(K, E, nMax)
%polarMotherLength Polar mother-code length N from K, E and n_max. Hand-written, not a toolbox call.
%Spec:   TS 38.212 V16.15.0, clause 5.3.1, the n = max{min{n_1, n_2, n_max}, n_min} construction.
%Inputs: K     positive integer -- information block length INCLUDING CRC
%        E     positive integer -- rate-matched output length
%        nMax  integer, 9 or 10 -- n_max
%Outputs: N  positive integer, a power of two -- the mother-code length
%
%WHY THIS EXISTS AT ALL
%----------------------
%The encoder never needs it: nrPolarEncode derives N internally from K and E, which is why
%phy.lib.ts38212.polarEncode takes E and not N. The DECODER does need it, because
%phy.lib.ts38212.polarDeRateMatch maps E soft values onto N and has to be told the target. The
%alternative -- encoding a dummy block just to read numel() off the result -- works and is what
%the first draft of the decode chains did, but it hides a real formula behind a side effect and
%costs a polar encode per received codeword.
%
%n_min = 5 is the floor: clause 5.3.1 fixes it, and it is why very short SCI payloads still use
%a 32-bit mother code rather than something smaller.

if ~(K >= 1 && mod(K, 1) == 0), error('lib:ts38212:polarMotherLength:badK', 'polarMotherLength: K must be a positive integer, got %s', num2str(K)); end
if ~(E >= 1 && mod(E, 1) == 0), error('lib:ts38212:polarMotherLength:badE', 'polarMotherLength: E must be a positive integer, got %s', num2str(E)); end
if ~any(nMax == [9 10]), error('lib:ts38212:polarMotherLength:badNMax', 'polarMotherLength: nMax must be 9 or 10, got %s', num2str(nMax)); end

nMin  = 5;
Rmin  = 1 / 8;
ceilE = ceil(log2(E));

% "if E <= (9/8)*2^(ceil(log2(E))-1) and K/E < 9/16, n_1 = ceil(log2(E)) - 1, else
%  n_1 = ceil(log2(E))". Both conditions, not either.
if E <= (9 / 8) * 2^(ceilE - 1) && (K / E) < (9 / 16)
    n1 = ceilE - 1;
else
    n1 = ceilE;
end
n2 = ceil(log2(K / Rmin));
n  = max(min([n1, n2, nMax]), nMin);
N  = 2^n;
end
