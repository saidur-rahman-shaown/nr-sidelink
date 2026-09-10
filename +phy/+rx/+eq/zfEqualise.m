function [eqSym, eqNoiseVar] = zfEqualise(rxSym, hEst, noiseVar)
%zfEqualise Zero-forcing equalisation, with the per-RE noise inflation it causes.
%Spec:   none -- equalisation is a receiver choice.
%Inputs: rxSym     N-by-1 complex -- received data symbols
%        hEst      N-by-1 complex -- channel estimate at those REs
%        noiseVar  real, >0 -- pre-equalisation noise variance per RE
%Outputs: eqSym       N-by-1 complex -- equalised symbols
%         eqNoiseVar  N-by-1 real -- POST-equalisation noise variance, per RE
%
%THE PER-RE NOISE VARIANCE IS RETURNED, AND IT IS NOT A CONSTANT
%----------------------------------------------------------------
%Zero forcing divides by the channel, so it divides the noise by the channel too: an RE in a
%fade comes out with its noise multiplied by 1/|h|^2. Handing the demodulator one scalar noise
%variance for the whole allocation tells it that a deeply faded RE is as reliable as a strong
%one, and the LLR magnitudes come out confidently wrong exactly where the errors are. Over AWGN
%the distinction vanishes (|h| is flat), which is why it survives a flat-channel test and only
%costs dB once a frequency-selective channel arrives.
%
%MMSE would be the better equaliser here -- it trades a little bias for not amplifying noise in
%a fade at all -- and is the obvious next module. Zero forcing is chosen first because it has no
%tuning and no dependence on the noise estimate, so a bug in the noise estimate cannot hide
%inside it.

if numel(rxSym) ~= numel(hEst)
    error('rx:eq:zfEqualise:sizeMismatch', 'zfEqualise: rxSym and hEst must be the same length');
end
h = hEst(:);
% Guard the division: a null in the estimate would otherwise produce Inf symbols that poison
% every LLR downstream rather than just the RE that was faded.
hSafe = h;
tiny  = abs(h) < eps;
hSafe(tiny) = eps;

eqSym      = rxSym(:) ./ hSafe;
eqNoiseVar = noiseVar ./ max(abs(hSafe).^2, eps);
end
