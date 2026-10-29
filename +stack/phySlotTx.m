function [iq, grid, info] = phySlotTx(g, startSubch, LsubCH, nsf, sci1a, sci2, tbBits, rv, pTxDbm, grid)
%phySlotTx One sidelink slot from SCI fields and a transport block to transmit IQ.
%Spec:   composes, in the slot-assembly order fixed in +phy/CLAUDE.md:
%          TS 38.212 8.3.1.1 / 8.4.1.1  SCI-1A and SCI-2A packing (sci1aPack, sci2aPack)
%          TS 38.212 8.3.2-8.3.4 + TS 38.211 8.3.2      PSCCH chain (phy.chan.pscchTx)
%          TS 38.211 8.3.1.1  N_ID = (decimal CRC on the associated PSCCH) mod 2^16
%          TS 38.212 8.2, 8.4 + TS 38.211 8.3.1, 8.4.1.1  PSSCH chain (phy.chan.psschTx)
%          TS 38.211 8.2.1    AGC duplicate (phy.ts38211.slAgcSymbol); guard symbol left empty
%          TS 38.211 5.3.1    OFDM (phy.lib.ofdmMod)
%          TS 38.213 16.2     power (phy.ts38213.slPowerControl), applied by rf.txFrontEnd
%Inputs: g          struct from stack.poolGeometry
%        startSubch, LsubCH  the allocation
%        nsf        integer -- slot number in the frame
%        sci1a      struct, sci1aPack's dynamicParams
%        sci2       struct, sci2aPack's dynamicParams
%        tbBits     tbs x 1 logical -- the MAC PDU (mac.muxSlSch output)
%        rv         integer, 0..3
%        pTxDbm     real -- transmit power, or NaN to return the grid only (iq empty) so the
%                   caller can add PSFCH to the same slot and modulate with stack.slotModulate
%        grid       optional nSubcarriers x 14 complex -- a slot grid to add to (e.g. one that
%                   already holds this UE's PSFCH); a fresh zero grid when omitted
%Outputs: iq    nSamples x 1 complex -- the slot as it leaves the UE, the input to a channel
%         grid  nSubcarriers x 14 complex -- the resource grid, for inspection
%         info  struct: .NID, .pscch (pscchTx info), .pssch (psschTx info), .fs (sample rate)
%
%N_ID IS DERIVED, NOT CHOSEN. TS 38.211 8.3.1.1: "N_ID equals the decimal representation of the
%CRC on the PSCCH associated with the PSSCH". +harness/+lls/linkConfig fixes it at 12345 because a
%link study needs one value; a real transmitter's PSSCH scrambling and DM-RS follow its own SCI,
%and a receiver recomputes the same number from the SCI it decodes.

CRC_BITS = 24;                                % TS 38.212 7.3.2, CRC24C on SCI
NID_MOD = 2^16;

m = stack.psschMapping(g, startSubch, LsubCH, nsf);
sci1aBits = phy.ts38212.sci1aPack(g.pool, sci1a);
sci2Bits = phy.ts38212.sci2aPack(sci2);
NID = stack.pscchCrcNid(sci1aBits, CRC_BITS, NID_MOD);

if nargin < 10 || isempty(grid)
    grid = complex(zeros(g.nSubcarriers, g.NsymbSlot));
end
[grid, pscchInfo] = phy.chan.pscchTx(grid, m.carrier, m.pscchCfg, sci1aBits);
psschCfg = phy.ts38211.slPSSCHConfig(struct(), struct('NID', NID, 'MbitSCI2', m.Gsci2, ...
    'modScheme', g.modScheme, 'nsf', nsf, 'NsymbSlot', g.NsymbSlot));
txp = struct('Gsci2', m.Gsci2, 'R', g.R, 'rv', rv, 'Qm', g.Qm, 'modScheme', g.modScheme, 'nlayers', 1);
[grid, psschInfo] = phy.chan.psschTx(grid, m.carrier, psschCfg, m.mapCfg, sci2Bits, tbBits, txp);
grid = phy.ts38211.slAgcSymbol(grid, g.firstSymbol, m.subcarriers);

info = struct('NID', NID, 'pscch', pscchInfo, 'pssch', psschInfo, 'fs', 0);
iq = complex(zeros(0, 1));
if ~isnan(pTxDbm)
    [iq, info.fs] = stack.slotModulate(g, grid, nsf, pTxDbm);
end
end
