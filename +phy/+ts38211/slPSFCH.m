function x = slPSFCH(carrier, cfg)
%slPSFCH PSFCH format 0 sequence generation.
%Spec:   TS 38.211 V16.10.0, clause 8.3.4.2.1
%Inputs: carrier  scalar struct, slCarrierConfig -- unused here, accepted for
%                 call-signature uniformity with the other channels
%        cfg      scalar struct from slPSFCHConfig()
%Outputs: x  12-by-1 complex column vector, x(0)..x(11), constant modulus
%
%PSFCH carries no coded codeword -- unlike PSCCH/PSSCH/PSBCH, there is no
%codedBits input. The 1-2 bit ACK/NACK value is conveyed entirely by WHICH
%cyclic shift (cfg.alpha) and resource the caller selected, per TS 38.213
%clause 16.3 -- 38.211's job is only to generate the sequence for a GIVEN
%alpha, exactly like nrPUCCH0 takes an already-chosen initial cyclic shift
%rather than deriving one from an ACK/NACK value itself.
%#ok<*INUSD>
x = phy.lib.lowPaprSeq(cfg.u, cfg.v, cfg.alpha, 12);
end
