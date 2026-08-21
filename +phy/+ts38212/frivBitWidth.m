function bits = frivBitWidth(Nsub, maxReserve)
%frivBitWidth Bit width of the SCI format 1-A "Frequency resource assignment" (FRIV) field.
%Spec:   TS 38.212 V16.15.0, clause 8.3.1.1 (formula body from TS 38.214 clause 8.1.5)
%Inputs: Nsub        integer, 1..27 -- higher-layer parameter sl-NumSubchannel
%        maxReserve  integer, 2 or 3 -- higher-layer parameter sl-MaxNumPerReserve
%Outputs: bits  ceil(log2(v)); v = Nsub*(Nsub+1)/2 when maxReserve==2, or
%               Nsub*(Nsub+1)*(2*Nsub+1)/6 when maxReserve==3
%
%bits==0 at Nsub==1 (v==1, only one legal sub-channel index exists) is intentional, not a bug --
%no floor-of-1 clamp is applied. This matches the same clause's own "0 bit otherwise" precedent
%for other conditionally-absent SCI-1A fields; confirmed via independent-verifier as the
%defensible literal reading (flagged there as needing an explicit decision, not a spec-stated
%certainty -- there is no floor(1,.) anywhere in TS 38.212 clause 8.3.1.1 or TS 38.214 clause
%8.1.5, and this codebase is choosing not to invent one).
if ~(Nsub >= 1 && Nsub <= 27 && mod(Nsub, 1) == 0)
    error('ts38212:frivBitWidth:badNsub', 'frivBitWidth: Nsub must be an integer in 1..27, got %s', num2str(Nsub));
end
if maxReserve == 2
    v = Nsub * (Nsub + 1) / 2;
elseif maxReserve == 3
    v = Nsub * (Nsub + 1) * (2 * Nsub + 1) / 6;
else
    error('ts38212:frivBitWidth:badMaxReserve', 'frivBitWidth: maxReserve must be 2 or 3, got %s', num2str(maxReserve));
end
bits = ceil(log2(v));
end
