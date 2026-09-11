function [grid, info] = psfchTx(grid, carrier, cfg)
%psfchTx PSFCH format 0: one PRB of sequence, repeated over two symbols, the first as AGC.
%Spec:   TS 38.211 V16.10.0 clause 8.3.4 (PSFCH), with the cyclic shift chosen by TS 38.213
%        clause 16.3 and supplied in cfg (see phy.ts38211.slPSFCHConfig).
%Inputs: grid     nSubcarriers-by-nSymbols complex matrix to write into
%        carrier  scalar struct, slCarrierConfig
%        cfg      scalar struct from phy.ts38211.slPSFCHConfig, with .alpha already resolved
%Outputs: grid  the input with both PSFCH symbols written
%         info  scalar struct: .ind (the content symbol's [k l]), .agcInd (the AGC symbol's),
%               .seq (the 12 transmitted values)
%
%PSFCH CARRIES NO CODEWORD
%--------------------------
%Unlike PSCCH, PSSCH and PSBCH there is no coded bit sequence here. The one or two HARQ-ACK bits
%are conveyed entirely by WHICH cyclic shift the caller selected, via
%phy.ts38213.psfchCyclicShiftMcs (0 for NACK, 6 for ACK) folded into alpha. So the transmit
%chain is a sequence generator and a mapper, and the receive side is a CORRELATOR rather than a
%decoder -- which is why phy.chan.psfchRx returns a detected shift and not a CRC.
%
%TWO SYMBOLS, ONE PRB, AND THE FIRST IS A DUPLICATE
%----------------------------------------------------
%+phy/+chan/CLAUDE.md names this as a trap: PSFCH "occupies 1 PRB repeated over 2 OFDM symbols
%with the first serving as AGC. Not a 2-PRB allocation, not a single symbol." The AGC symbol
%carries the identical 12 values -- a receiver that has settled its gain can use it, but its
%purpose is to let the gain settle at all. Writing only the content symbol leaves the first
%symbol of the PSFCH region empty, which on real hardware is exactly the AGC transient the
%duplication exists to absorb.

ind = phy.ts38211.slPSFCHIndices(carrier, cfg);
seq = phy.ts38211.slPSFCH(carrier, cfg);

% The AGC symbol is the one immediately before the content symbol, same subcarriers.
agcInd = ind;
agcInd(:, 2) = ind(:, 2) - 1;
if any(agcInd(:, 2) < 0)
    error('chan:psfchTx:noRoomForAgc', 'psfchTx: the content symbol is at l=%d, leaving no preceding symbol for the AGC duplicate', ind(1, 2));
end

grid(sub2ind(size(grid), agcInd(:, 1) + 1, agcInd(:, 2) + 1)) = seq;
grid(sub2ind(size(grid), ind(:, 1) + 1,    ind(:, 2) + 1))    = seq;

info = struct('ind', ind, 'agcInd', agcInd, 'seq', seq);
end
