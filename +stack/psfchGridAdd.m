function grid = psfchGridAdd(grid, g, nsf, prbAbs, m0, ackBit)
%psfchGridAdd Write one PSFCH (HARQ-ACK) onto a slot grid.
%Spec:   TS 38.213 V16.17.0 clause 16.3 (the HARQ-ACK value picks the cyclic shift: Table 16.3-2,
%        0 for NACK, 6 for ACK, via phy.ts38213.psfchCyclicShiftMcs) and TS 38.211 V16.10.0 clause
%        8.3.4 (sequence and mapping, via phy.chan.psfchTx, which also writes the AGC copy on
%        l'-1).
%Inputs: grid    nSubcarriers x 14 complex
%        g       struct from stack.poolGeometry
%        nsf     integer -- slot number in the frame
%        prbAbs  integer -- the PSFCH PRB (stack.psfchResourceFor)
%        m0      integer -- the cyclic-shift pair value (stack.psfchResourceFor)
%        ackBit  integer, 0 (NACK) or 1 (ACK)
%Outputs: grid  with the PSFCH's two symbols written
%
%Unicast reporting is ACK-or-NACK (Table 16.3-2), so ackNackOnly is false here.
ACK_NACK_ONLY = false;
dp = struct('m0', m0, 'mcs', phy.ts38213.psfchCyclicShiftMcs(ackBit, ACK_NACK_ONLY), ...
    'lp', g.psfchSymbol, 'nsf', nsf, 'NsymbSlot', g.NsymbSlot, 'startPRB', prbAbs, 'symbol', g.psfchSymbol);
cfgP = phy.ts38211.slPSFCHConfig(g.psfchCfg, dp);
grid = phy.chan.psfchTx(grid, struct(), cfgP);
end
