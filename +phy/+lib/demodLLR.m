function llr = demodLLR(symbols, modulation, noiseVar)
%demodLLR Soft demodulation to log-likelihood ratios. Toolbox body: nrSymbolDemodulate.
%Spec:   the soft inverse of TS 38.211 V16.10.0 clause 5.1 (modulation mapper). Demodulation is
%        not normative; only the constellation it inverts is.
%Inputs: symbols     nSym-by-1 complex column vector -- equalised received symbols
%        modulation  char, one of 'BPSK','QPSK','16QAM','64QAM','256QAM'
%        noiseVar    real, >0 -- post-equalisation noise variance per symbol
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
if ~(isscalar(noiseVar) && isreal(noiseVar) && noiseVar > 0)
    error('lib:demodLLR:badNoiseVar', 'demodLLR: noiseVar must be a positive real scalar, got %s', mat2str(noiseVar));
end

llr = nrSymbolDemodulate(symbols(:), modulation, noiseVar);
end
