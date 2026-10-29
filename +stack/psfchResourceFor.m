function [prbAbs, m0] = psfchResourceFor(g, startSubch, sourceId)
%psfchResourceFor The PSFCH PRB and cyclic-shift m0 that carry feedback for one PSSCH.
%Spec:   TS 38.213 V16.17.0 clause 16.3: the PRB range of (PSSCH slot i, sub-channel j)
%        (phy.ts38213.psfchPrbRange), the resource index (P_ID + M_ID) mod R_PRB,CS split into PRB
%        and cyclic-shift pair (phy.ts38213.psfchResource), m0 from Table 16.3-1
%        (phy.ts38213.psfchCyclicShiftM0); TS 38.331 sl-PSFCH-RB-Set ("the leftmost bit ... refers
%        to the lowest RB index in the resource pool") for the PRB's absolute position.
%Inputs: g           struct from stack.poolGeometry (g.psfchPeriod must be 1)
%        startSubch  integer, 0..numSubchannel-1 -- the PSSCH's starting sub-channel (startSubCH)
%        sourceId    integer, 0..255 -- P_ID: SCI-2A's Source ID of the PSSCH being acknowledged
%Outputs: prbAbs  integer -- the PSFCH PRB, BWP-relative
%         m0      integer, 0..11
%
%BOTH ENDS CALL THIS WITH THE SAME INPUTS, AND THAT IS THE WHOLE ADDRESSING SCHEME
%----------------------------------------------------------------------------------
%The receiver of the PSSCH sends its ACK/NACK here; the transmitter of the PSSCH listens here.
%Neither signals the resource: it is derived from the PSSCH's sub-channel and the transmitter's
%8-bit Source ID, which both sides know. M_ID is 0: it is non-zero only for groupcast cast type
%"01" (per-member ACK/NACK), and feedback is enabled here for unicast only.
%
%i, the PSSCH slot's index among the slots sharing a PSFCH occasion, is 0 because with
%sl-PSFCH-Period 1 each PSSCH slot has its own occasion (poolGeometry asserts the period).
N_TYPE_START_SUBCH = 1;              % TS 38.213 16.3, startSubCH
M_ID_NOT_GROUPCAST01 = 0;
I_SLOT_PERIOD1 = 0;
if g.psfchPeriod ~= 1
    error('stack:psfchResourceFor:period', 'psfchResourceFor: only sl-PSFCH-Period 1 is supported');
end
[prbStart, ~, M] = phy.ts38213.psfchPrbRange(I_SLOT_PERIOD1, startSubch, g.psfchMPrbSet, g.numSubchannel, g.psfchPeriod);
[prb, csPair] = phy.ts38213.psfchResource(prbStart, M, N_TYPE_START_SUBCH, g.psfchNcs, sourceId, M_ID_NOT_GROUPCAST01);
prbAbs = g.psfchRbAbs(prb + 1);
m0 = phy.ts38213.psfchCyclicShiftM0(csPair, g.psfchNcs);
end
