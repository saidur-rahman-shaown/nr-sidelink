function mcs = psfchCyclicShiftMcs(harqAckBit, ackNackOnly)
%psfchCyclicShiftMcs mcs value for a PSFCH cyclic shift, from the HARQ-ACK bit value.
%Spec:   TS 38.213 V16.17.0, clause 16.3, Table 16.3-2 (ACK-or-NACK case) / Table 16.3-3
%        (NACK-only case)
%Inputs: harqAckBit   integer, 0 or 1 -- the HARQ-ACK information bit value (0=NACK, 1=ACK)
%        ackNackOnly  logical scalar -- false if the UE detects SCI format 2-A with Cast type
%                     indicator "01" or "10" (Table 16.3-2, ACK-or-NACK reporting); true if the
%                     UE detects SCI format 2-B, or SCI format 2-A with Cast type indicator
%                     "11" (Table 16.3-3, NACK-only reporting -- harqAckBit=1/ACK has no
%                     defined cyclic shift in this case and is rejected)
%Outputs: mcs  integer, 0 or 6 -- the mcs value; feeds TS 38.211's cyclic shift alpha formula
%              (phy.ts38211.slPSFCHAlpha)
%
%Tables confirmed by independent-verifier, including that Table 16.3-3's "1 (ACK)" column
%contains the literal spec text "N/A", not a blank -- rejecting harqAckBit=1 in this mode is
%the spec-correct behaviour, not a stand-in default.
if ~(harqAckBit == 0 || harqAckBit == 1)
    error('ts38213:psfchCyclicShiftMcs:badBit', 'psfchCyclicShiftMcs: harqAckBit must be 0 or 1, got %s', num2str(harqAckBit));
end
if ackNackOnly
    if harqAckBit == 1
        error('ts38213:psfchCyclicShiftMcs:ackNotApplicable', 'psfchCyclicShiftMcs: Table 16.3-3 (NACK-only) has no cyclic shift for harqAckBit=1 (ACK)');
    end
    mcs = 0;
else
    if harqAckBit == 0
        mcs = 0;
    else
        mcs = 6;
    end
end
end
