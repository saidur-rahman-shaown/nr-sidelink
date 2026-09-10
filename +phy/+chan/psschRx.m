function [sci2Bits, sci2Ok, tbBits, tbOk] = psschRx(eqSymbols, carrier, cfg, info, A2, rxp)
%psschRx PSSCH receive chain: equalised symbols to SCI-2 and the transport block.
%Spec:   the inverse of TS 38.211 clause 8.3.1 (descramble, demap) and TS 38.212 clauses 8.2.1,
%        8.4.2-8.4.4 and 6.2.1-6.2.6, via sci2ChainDecode and slSchDecode.
%Inputs: eqSymbols  nTotal-by-1 complex column -- the PSSCH REs in mapping order (SCI-2 portion
%                   first, then data), **already equalised**. Channel estimation and
%                   equalisation live in +phy/+rx/
%        carrier    scalar struct, slCarrierConfig
%        cfg        scalar struct from phy.ts38211.slPSSCHConfig
%        info       the struct psschTx returned: .Msymb1, .Gsci2, .Gslsch
%        A2         positive integer -- SCI-2 payload length (35 for 2-A, 48 for 2-B)
%        rxp        scalar struct: .R .rv .modScheme .nlayers .trblklen .noiseVar .listSize
%                   .maxIter
%Outputs: sci2Bits  A2-by-1 logical -- ready for sci2aUnpack / sci2bUnpack
%         sci2Ok    logical -- SCI-2 CRC
%         tbBits    trblklen-by-1 logical -- the transport block
%         tbOk      logical -- the TRANSPORT-block CRC, i.e. the PSSCH block-error indication
%
%TWO STREAMS, TWO MODULATIONS, AND A SCRAMBLING SEQUENCE THAT RESTARTS
%----------------------------------------------------------------------
%The SCI-2 portion is always QPSK and the data portion runs at the signalled MCS, so they are
%demodulated separately. The scrambling is the subtle part: clause 8.3.1.1 applies c(i - M~_i,j)
%with M~_i,j = 0 over the SCI-2 portion and M~_i,j = M_bit,SCI2 over the data portion -- so **the
%same sequence is used twice, restarted at the boundary**, not run continuously across the
%concatenation. phy.ts38211.slPSSCHScramble implements exactly that on the transmit side, and
%the descrambling sequence below is built to mirror it index for index rather than being
%re-derived from the clause independently.
%
%Treating it as one continuous run is the error to watch for, and it is silent: the SCI-2
%portion still descrambles correctly (its offset is 0 either way), so the control channel
%decodes, the receiver looks alive, and only the transport block fails -- at every SNR, which
%reads as a coding or rate-matching fault rather than a scrambling one.
%
%SCI-2 IS DECODED EVEN WHEN THE DATA FAILS, AND THAT IS THE POINT
%------------------------------------------------------------------
%They are independently coded. A receiver at range routinely recovers the control and loses the
%data, which is exactly the case that yields a NACK rather than a DTX -- see
%+harness/+sls/slotStep on why owing feedback on the control decode rather than the data decode
%is what keeps a lossy-but-alive link from being declared dead.

Msymb1 = info.Msymb1;
nTotal = numel(eqSymbols);
if nTotal <= Msymb1
    error('chan:psschRx:tooFewSymbols', 'psschRx: %d symbols cannot hold a %d-symbol SCI-2 plus data', nTotal, Msymb1);
end

% Demodulate each portion at its own modulation, then join in bit order. The noise variance is
% sliced with the symbols when it is per-RE: zero forcing makes it vary across the allocation,
% and handing the SCI-2 demapper the data portion's variances (or vice versa) misweights every
% LLR in the block.
if isscalar(rxp.noiseVar)
    nvSci2 = rxp.noiseVar;
    nvData = rxp.noiseVar;
else
    if numel(rxp.noiseVar) ~= nTotal
        error('chan:psschRx:noiseVarLength', 'psschRx: a per-RE noiseVar must be %d long, got %d', nTotal, numel(rxp.noiseVar));
    end
    nvSci2 = rxp.noiseVar(1:Msymb1);
    nvData = rxp.noiseVar(Msymb1 + 1:end);
end
llrSci2 = phy.lib.demodLLR(eqSymbols(1:Msymb1), 'QPSK', nvSci2);
llrData = phy.lib.demodLLR(eqSymbols(Msymb1 + 1:end), rxp.modScheme, nvData);
llr     = [llrSci2; llrData];

% cinit for PSSCH is 2^15 * N_ID + 1010, with N_ID the PSCCH CRC -- kept visible at the call
% site per +phy/+chan/CLAUDE.md rather than hidden in a helper. The sequence restarts at the
% SCI-2/data boundary; see the header.
psschCinit = 2^15 * cfg.NID + 1010;
Mbit       = numel(llr);
MbitSCI2   = info.Gsci2;
c          = phy.lib.goldSeq(psschCinit, Mbit);
seq        = [c(1:MbitSCI2); c(1:Mbit - MbitSCI2)];
llr        = llr .* (1 - 2 * double(seq));

[sci2Bits, sci2Ok] = phy.ts38212.sci2ChainDecode(llr(1:info.Gsci2), A2, rxp.listSize);
[tbBits, tbOk]     = phy.ts38212.slSchDecode(llr(info.Gsci2 + 1:end), rxp.trblklen, ...
    rxp.R, rxp.rv, rxp.modScheme, rxp.nlayers, rxp.maxIter);
end
