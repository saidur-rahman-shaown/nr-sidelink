function alpha = slPSFCHAlpha(m0, mcs, hopId, lp, nsf, NsymbSlot)
%slPSFCHAlpha PSFCH format 0 cyclic shift alpha.
%Spec:   TS 38.211 V16.10.0, clause 6.3.2.2.2 (as applied via clause 8.3.4.2.1)
%Inputs: m0         integer, 0..11 -- TS 38.213 Table 16.3-1 cyclic shift pair
%                   value (not computed here: which pair/value applies is a
%                   38.213 resource-determination procedure, not a 38.211
%                   modulation formula -- caller supplies it, computed via
%                   phy.ts38213.psfchCyclicShiftM0)
%        mcs        integer, 0..11 -- TS 38.213 Table 16.3-2/16.3-3 HARQ-ACK
%                   cyclic shift (0 for NACK, 6 for ACK; caller-supplied for
%                   the same reason as m0, computed via
%                   phy.ts38213.psfchCyclicShiftMcs)
%        hopId      integer, 0..1023 -- higher-layer parameter sl-PSFCH-HopID
%                   if configured, else 0 (this is the PSFCH sequence cinit,
%                   same value slPSFCH's u/v derivation already uses)
%        lp         integer, >=0 -- l', the slot-relative index of the SECOND
%                   (content) OFDM symbol of the PSFCH transmission
%        nsf        integer, >=0 -- slot number within a radio frame, n_{s,f}^mu
%        NsymbSlot  integer, >0 -- OFDM symbols per slot (14 or 12)
%Outputs: alpha  double, radians -- the cyclic shift for phy.lib.lowPaprSeq()
%
%alpha = (2*pi/12) * mod(m0 + mcs + n_cs, 12)
%n_cs = sum_{m=0}^{7} 2^m * c(8*NsymbSlot*nsf + 8*lp + m)
%c(i) is the clause 5.2.1 Gold sequence, c_init = hopId, reset each radio
%frame (i.e. nsf is slot-within-frame, not an absolute slot counter, matching
%the same n_{s,f}^mu convention already used throughout +phy/+ts38211/).
if m0 < 0 || m0 > 11 || mod(m0,1) ~= 0
    error('ts38211:slPSFCHAlpha:badM0', 'slPSFCHAlpha: m0 must be an integer in 0..11, got %s', mat2str(m0));
end
if mcs < 0 || mcs > 11 || mod(mcs,1) ~= 0
    error('ts38211:slPSFCHAlpha:badMcs', 'slPSFCHAlpha: mcs must be an integer in 0..11, got %s', mat2str(mcs));
end
if hopId < 0 || hopId > 1023 || mod(hopId,1) ~= 0
    error('ts38211:slPSFCHAlpha:badHopId', 'slPSFCHAlpha: hopId must be an integer in 0..1023, got %s', mat2str(hopId));
end
if lp < 0 || mod(lp,1) ~= 0
    error('ts38211:slPSFCHAlpha:badLp', 'slPSFCHAlpha: lp must be a nonnegative integer, got %s', mat2str(lp));
end
if nsf < 0 || mod(nsf,1) ~= 0
    error('ts38211:slPSFCHAlpha:badNsf', 'slPSFCHAlpha: nsf must be a nonnegative integer, got %s', mat2str(nsf));
end
if NsymbSlot <= 0 || mod(NsymbSlot,1) ~= 0
    error('ts38211:slPSFCHAlpha:badNsymbSlot', 'slPSFCHAlpha: NsymbSlot must be a positive integer, got %s', mat2str(NsymbSlot));
end
i0 = 8*NsymbSlot*nsf + 8*lp;
c = phy.lib.goldSeq(hopId, i0 + 8);
bits = double(c(i0+1:i0+8));
ncs = sum((2.^(0:7))' .* bits);
alpha = (2*pi/12) * mod(m0 + mcs + ncs, 12);
end
