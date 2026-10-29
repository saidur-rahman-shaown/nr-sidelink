function m = psschMapping(g, startSubch, LsubCH, nsf)
%psschMapping PSCCH and PSSCH resource layout for one allocation on the BWP grid.
%Spec:   none itself. Composes TS 38.214 clause 8.1.2.2 (the PSCCH sits in the lowest sub-channel
%        of the allocation, starting at its first PRB, over sl-FreqResourcePSCCH PRBs and
%        sl-TimeResourcePSCCH symbols after the duplicated symbol), TS 38.211 8.3.1.5 / 8.3.2.3 /
%        8.4.1.1 (via slPSCCHIndices, slPSCCHDMRSIndices, slPSSCHIndices), and TS 38.212 8.4.4
%        (G^SCI2 via phy.ts38212.sci2OutputLength). The same derivation +harness/+lls/linkConfig
%        makes, but placed at the pool's sub-channel position on the full BWP grid instead of on
%        a grid exactly one allocation wide.
%Inputs: g           struct from stack.poolGeometry
%        startSubch  integer, 0..numSubchannel-1 -- the allocation's lowest sub-channel
%        LsubCH      integer, 1..numSubchannel-startSubch -- allocation width in sub-channels
%        nsf         integer, 0..10*2^mu-1 -- slot number in the frame (DM-RS initialisation)
%Outputs: m  scalar struct:
%            .carrier    the (empty) slCarrierConfig the chains take
%            .pscchCfg   phy.ts38211.slPSCCHConfig output
%            .pscchRE    [k l] of the PSCCH and its DM-RS
%            .mapCfg     slPSSCHIndices config with .Msymb1 filled
%            .Gsci2      G^SCI2, made even for QPSK
%            .startPRB .NRB      the allocation's PRBs
%            .subcarriers        0-based subcarriers of the allocation (for the AGC copy)
%
%gamma (TS 38.212 8.4.4's vacant-RE term) is taken as 0 and G^SCI2 rounded up to even -- the
%choice +harness/+lls/linkConfig makes, kept identical so the link-level BLER table and this
%chain describe the same waveform.

SUBCARRIERS_PER_RB = 12;
QPSK_BITS = 2;
if ~(startSubch >= 0 && LsubCH >= 1 && startSubch + LsubCH <= g.numSubchannel)
    error('stack:psschMapping:badAllocation', 'psschMapping: sub-channels %d..%d exceed the pool', startSubch, startSubch + LsubCH - 1);
end
m.carrier = struct();
m.startPRB = g.subchStartRb(startSubch + 1);
m.NRB = LsubCH * g.subchSizeRb;
pscchSyms = g.firstSymbol + (0:g.pscchSymbols - 1);
m.pscchCfg = phy.ts38211.slPSCCHConfig(g.pool.sl_PSCCH_Config_r16, struct( ...
    'startPRB', m.startPRB, 'NRB', g.pscchPrb, 'symbols', pscchSyms, 'nsf', nsf, 'NsymbSlot', g.NsymbSlot));
m.pscchRE = [phy.ts38211.slPSCCHIndices(m.carrier, m.pscchCfg); ...
             phy.ts38211.slPSCCHDMRSIndices(m.startPRB, g.pscchPrb, pscchSyms)];
m.mapCfg = struct('startPRB', m.startPRB, 'NRB', m.NRB, 'ld', g.slStartSymbol + g.ld, ...
    'dmrsSymbols', g.slStartSymbol + g.dmrsSymbols, 'Msymb1', 0, 'pscchRE', m.pscchRE, ...
    'ptrsRE', zeros(0, 2), 'csirsRE', zeros(0, 2));
sumMscSci2 = size(phy.ts38211.slPSSCHIndices(m.carrier, m.mapCfg), 1);
m.Gsci2 = phy.ts38212.sci2OutputLength(g.sci2BitLen, g.beta, g.R, g.alpha, sumMscSci2, 0);
if mod(m.Gsci2, QPSK_BITS) ~= 0
    m.Gsci2 = m.Gsci2 + 1;
end
m.mapCfg.Msymb1 = m.Gsci2 / QPSK_BITS;
m.subcarriers = m.startPRB * SUBCARRIERS_PER_RB + (0:m.NRB * SUBCARRIERS_PER_RB - 1);
end
