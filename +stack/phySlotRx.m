function [rx, grid, powerCal] = phySlotRx(g, iq, nsf, listSize, maxIter, decodePssch)
%phySlotRx Receive one sidelink slot: blind PSCCH search, then every PSSCH it announces.
%Spec:   the inverse chain. Non-normative receiver steps (+phy/+rx/: blind detection, DM-RS channel
%        estimation, ZF equalisation; +phy/+lib/: OFDM demodulation) feed the normative inverses
%        (phy.chan.pscchRx inside pscchSearch, phy.chan.psschRx). Everything about the PSSCH --
%        its width (FRIV, phy.ts38212.frivLsubch), MCS, DM-RS pattern, beta offset, N_ID (the PSCCH
%        CRC), the TBS -- is taken from the decoded SCI-1A, never from the transmitter.
%Inputs: g         struct from stack.poolGeometry -- the RECEIVE side's own view of the pool
%        iq        nSamples x 1 complex -- the received slot, time aligned (sync is idealised)
%        nsf       integer -- slot number in the frame
%        listSize  integer, polar SCL list size
%        maxIter   integer, LDPC iterations
%        decodePssch  logical, optional (default true) -- false to demodulate only: the UE
%                  transmitted PSCCH/PSSCH in this slot and, half duplex, heard none of it, but it
%                  may still detect PSFCH in the slot's last symbols (stack.rxSlot)
%Outputs: rx  1 x n struct array, one per PSCCH found:
%            .startSubch .LsubCH   the allocation
%            .sci1a                sci1aUnpack output
%            .sci2Ok .sci2         SCI-2A CRC and fields (sci2aUnpack)
%            .tbOk .tbBits         transport block CRC and bits
%            .rsrpDbm              PSSCH-RSRP (TS 38.215 5.1.23, phy.ts38215.slRsrp) for sensing
%            .dataLlr .trblklen .R .modScheme   the SL-SCH LLRs and decode parameters, so the
%                                  caller can soft-combine a retransmission (stack.harqCombineDecode);
%                                  .tbOk is this transmission decoded ALONE
%         grid      nSubcarriers x 14 complex -- the demodulated slot (for PSFCH detection)
%         powerCal  real -- W per |RE|^2, see below
%
%RSRP needs RE powers in watts. iq is in sqrt(W) (rf.txFrontEnd), but the OFDM demodulator's own
%normalisation is not a power calibration, so the grid is scaled once per slot such that, summed
%over a symbol's REs, power equals the mean power of that symbol in the time domain -- clause
%5.1.23's "power contributions (in [W]) of the resource elements".
%
%The amplitude of iq is irrelevant: the DM-RS-based estimate absorbs it. The receiver needs only
%the grid width and the numerology, which are configuration.

rx = repmat(struct('startSubch', 0, 'LsubCH', 0, 'sci1a', struct(), 'sci2Ok', false, ...
    'sci2', struct(), 'tbOk', false, 'tbBits', false(0, 1), 'rsrpDbm', -Inf, ...
    'dataLlr', zeros(0, 1), 'trblklen', 0, 'R', 0, 'modScheme', ''), 1, 0);
grid = phy.lib.ofdmDemod(iq, g.nSubcarriers, g.mu, nsf);
SUBCARRIERS_PER_RB = 12;                     % TS 38.211 4.4.4.1
gridPower = sum(abs(grid(:)).^2);
powerCal = 0;
if gridPower > 0
    powerCal = mean(abs(iq).^2) * size(grid, 2) / gridPower;     % W per |RE|^2
end
template = stack.psschMapping(g, 0, 1, nsf);
A = numel(phy.ts38212.sci1aPack(g.rxPool, struct('priority', 1, 'friv', 0, 'triv', 0, ...
    'reservationPeriodIndex', 0, 'dmrsPatternIndex', 0, 'sci2Format', 'A', 'betaOffsetIndex', 0, ...
    'numDmrsPort', 0, 'mcs', 0, 'additionalMcsTableIndex', 0, 'psfchOverhead', 0)));
if nargin >= 6 && ~decodePssch
    return;
end
[found, bits] = phy.rx.det.pscchSearch(grid, template.carrier, template.pscchCfg, ...
    g.numSubchannel, g.subchSizeRb, A, 0, listSize);

for x = find(found) - 1
    sci1a = phy.ts38212.sci1aUnpack(bits(:, x + 1), g.rxPool);
    L = phy.ts38212.frivLsubch(sci1a.friv, g.numSubchannel, g.maxNumPerReserve);
    if x + L > g.numSubchannel
        continue;                               % an SCI whose allocation runs off the pool
    end
    [gs, tbsBits] = stack.applySci(g, sci1a, L);
    m = stack.psschMapping(gs, x, L, nsf);
    NID = stack.pscchCrcNid(bits(:, x + 1), 24, 2^16);
    cfgS = phy.ts38211.slPSSCHConfig(struct(), struct('NID', NID, 'MbitSCI2', m.Gsci2, ...
        'modScheme', gs.modScheme, 'nsf', nsf, 'NsymbSlot', gs.NsymbSlot));
    dataInd = phy.ts38211.slPSSCHIndices(m.carrier, m.mapCfg);
    dmrsInd = phy.ts38211.slPSSCHDMRSIndices(m.startPRB, m.NRB, m.mapCfg.dmrsSymbols);
    nDataRE = size(dataInd, 1) - m.mapCfg.Msymb1;
    info = struct('Gsci2', m.Gsci2, 'Gslsch', nDataRE * gs.Qm, 'Msymb1', m.mapCfg.Msymb1, ...
        'dataInd', dataInd, 'dmrsInd', dmrsInd, 'nDataRE', nDataRE);

    [sym, dmrsSym] = phy.rx.ce.gridExtract(grid, dataInd, dmrsInd);
    ref = refDmrs(m, NID, nsf, gs.NsymbSlot);
    % Noise + interference per sub-channel, not per allocation: a partial collision must turn
    % the collided sub-channel's LLRs into erasures, or HARQ combining carries them into the
    % retransmission (see phy.rx.ce.dmrsEstimate).
    [h, nv] = phy.rx.ce.dmrsEstimate(dmrsSym, ref, dmrsInd, dataInd, g.nSubcarriers, g.subchSizeRb * SUBCARRIERS_PER_RB);
    [eq, eqNv] = phy.rx.eq.zfEqualise(sym, h, nv);
    rxp = struct('R', gs.R, 'rv', sci2RvUnknown(), 'modScheme', gs.modScheme, 'nlayers', 1, ...
        'trblklen', tbsBits, 'noiseVar', eqNv, 'listSize', listSize, 'maxIter', maxIter);
    % The RV is in SCI-2, which is decoded from the same symbols before the data. psschRx decodes
    % both in one call, so decode SCI-2 first at a nominal RV, read the RV, then decode with it.
    [sci2Bits, sci2Ok] = phy.chan.psschRx(eq, m.carrier, cfgS, info, gs.sci2BitLen, rxp);
    sci2 = struct();
    tbOk = false; tbBits = false(0, 1);
    if sci2Ok
        sci2 = phy.ts38212.sci2aUnpack(sci2Bits);
        rxp.rv = sci2.rv;
        [~, ~, tbBits, tbOk] = phy.chan.psschRx(eq, m.carrier, cfgS, info, gs.sci2BitLen, rxp);
    end
    [~, rsrpDbm] = phy.ts38215.slRsrp(grid * sqrt(powerCal), dmrsInd, 'pssch');
    llr = zeros(0, 1);
    if sci2Ok
        llr = dataLlr(eq, info, gs.modScheme, eqNv, NID);
    end
    rx(end + 1) = struct('startSubch', x, 'LsubCH', L, 'sci1a', sci1a, 'sci2Ok', sci2Ok, ...
        'sci2', sci2, 'tbOk', tbOk, 'tbBits', logical(tbBits(:)), 'rsrpDbm', rsrpDbm, ...
        'dataLlr', llr, 'trblklen', tbsBits, 'R', gs.R, 'modScheme', gs.modScheme); %#ok<AGROW>
end
end

function llr = dataLlr(eqSym, info, modScheme, eqNv, NID)
% The SL-SCH portion's descrambled LLRs, mirroring phy.chan.psschRx (TS 38.211 8.3.1.1: one Gold
% sequence with c_init = N_ID x 2^15 + 1010, RESTARTED at the SCI-2/data boundary), and the same
% routine +harness/+lls/linkSlot uses for its combining.
CINIT_OFFSET = 1010; CINIT_SHIFT = 2^15;
Msymb1 = info.Msymb1;
if isscalar(eqNv)
    nvS = eqNv; nvD = eqNv;
else
    nvS = eqNv(1:Msymb1); nvD = eqNv(Msymb1 + 1:end);
end
llrAll = [phy.lib.demodLLR(eqSym(1:Msymb1), 'QPSK', nvS); ...
          phy.lib.demodLLR(eqSym(Msymb1 + 1:end), modScheme, nvD)];
c = phy.lib.goldSeq(CINIT_SHIFT * NID + CINIT_OFFSET, numel(llrAll));
seq = [c(1:info.Gsci2); c(1:numel(llrAll) - info.Gsci2)];
llrAll = llrAll .* (1 - 2 * double(seq));
llr = llrAll(info.Gsci2 + 1:end);
end

function rv = sci2RvUnknown()
% Any legal RV: the first psschRx call only needs the SCI-2 half, which does not depend on it.
rv = 0;
end

function ref = refDmrs(m, NID, nsf, NsymbSlot)
% The PSSCH DM-RS a transmitter with this N_ID would have sent, symbol by symbol -- the same
% generation phy.chan.psschTx performs (one sequence per symbol: c_init walks with l).
nPerSym = 6 * m.NRB;
syms = m.mapCfg.dmrsSymbols;
ref = complex(zeros(nPerSym * numel(syms), 1));
for s = 1:numel(syms)
    ref((s - 1) * nPerSym + (1:nPerSym)) = phy.ts38211.slPSSCHDMRS(NID, syms(s), nsf, NsymbSlot, nPerSym);
end
end
