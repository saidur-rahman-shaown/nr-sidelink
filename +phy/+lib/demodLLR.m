function llr = demodLLR(symbols, modulation, noiseVar)
%demodLLR Soft demodulation to log-likelihood ratios. Toolbox body: nrSymbolDemodulate.
%Spec:   the soft inverse of TS 38.211 V16.10.0 clause 5.1 (modulation mapper). Demodulation is
%        not normative; only the constellation it inverts is.
%Inputs: symbols     nSym-by-1 complex column vector -- equalised received symbols
%        modulation  char, one of 'BPSK','QPSK','16QAM','64QAM','256QAM'
%        noiseVar    real, >0 -- post-equalisation noise variance. Either a scalar for the
%                    whole block, or an nSym-by-1 vector giving it PER SYMBOL. The vector form
%                    is what phy.rx.eq.zfEqualise produces: zero forcing divides the noise by
%                    the channel, so an RE in a fade comes out far noisier than a strong one,
%                    and collapsing that to a scalar tells the decoder a faded RE is as
%                    reliable as a clean one -- confidently wrong LLRs exactly where the errors
%                    are
%Outputs: llr  (nSym*Qm)-by-1 real column vector -- LLRs in the bit order clause 5.1 maps,
%              **negative for a probable 1**
%
%SIGN CONVENTION, WHICH IS THE ONE THING TO GET RIGHT HERE
%----------------------------------------------------------
%nrSymbolDemodulate returns LLRs that are negative where bit 1 is more likely, matching
%nrPolarDecode's and nrLDPCDecode's expected input. That is the opposite of the log(P0/P1)
%convention many texts use. It is preserved here rather than normalised, because every consumer
%in this tree is a toolbox decoder expecting exactly this sign -- flipping it would produce a
%decoder that fails only at low SNR, where it looks like a channel problem rather than a sign
%problem.
%
%Descrambling on LLRs is a sign flip, not an XOR: where the scrambling sequence bit is 1 the
%LLR's sign is inverted. See phy.chan.pscchRx and psschRx, which do that at the call site so
%the per-channel cinit derivation stays visible there, as +phy/+chan/CLAUDE.md requires.

legal = {'BPSK', 'QPSK', '16QAM', '64QAM', '256QAM'};
if ~ismember(modulation, legal)
    error('lib:demodLLR:badModulation', 'demodLLR: "%s" is not one of BPSK/QPSK/16QAM/64QAM/256QAM', modulation);
end
if ~isreal(noiseVar) || any(noiseVar(:) <= 0)
    error('lib:demodLLR:badNoiseVar', 'demodLLR: noiseVar must be positive and real');
end
nSym = numel(symbols);
if ~isscalar(noiseVar) && numel(noiseVar) ~= nSym
    error('lib:demodLLR:noiseVarLength', 'demodLLR: a per-symbol noiseVar must be %d long, got %d', nSym, numel(noiseVar));
end

if isscalar(noiseVar)
    llr = nrSymbolDemodulate(symbols(:), modulation, noiseVar);
    return;
end

% Per-symbol variance. Demodulate once at unit variance, then scale each symbol's Qm LLRs by
% 1/nv. Gray-mapped LLRs are inversely proportional to the noise variance, so the scaling is
% exact rather than an approximation -- and doing it this way calls the toolbox demapper once
% instead of once per symbol.
llrUnit = nrSymbolDemodulate(symbols(:), modulation, 1);
Qm      = numel(llrUnit) / nSym;
scale   = repelem(1 ./ noiseVar(:), Qm);
llr     = llrUnit .* scale;
end
