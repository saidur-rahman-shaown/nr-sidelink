function G = sci2OutputLength(OSCI2, betaOffset, R, alpha, sumMscSci2, gamma)
%sci2OutputLength SCI-2 rate-matched (and modulation-symbol-scaled) output bit length G^SCI2.
%Spec:   TS 38.212 V16.15.0, clause 8.4.4
%Inputs: OSCI2       nonnegative integer -- O^SCI2, number of 2nd-stage SCI information bits
%                    (numel of sci2aPack's/sci2bPack's output)
%        betaOffset  real scalar, >0 -- beta_offset^SCI2, indicated by the corresponding
%                    1st-stage SCI's beta-offset indicator field, resolved against the pool's
%                    sl-BetaOffsets2ndSCI list (not resolved here -- caller-supplied)
%        R           real scalar, 0..1 -- coding rate indicated by the "Modulation and coding
%                    scheme" field in SCI format 1-A
%        alpha       real scalar, 0..1 -- higher-layer parameter sl-Scaling
%        sumMscSci2  nonnegative integer -- sum over l=0..Nsymb-1 of M_sc^SCI2(l), the number
%                    of REs available for 2nd-stage SCI per OFDM symbol in the PSSCH region
%                    (M_sc^PSSCH(l) minus M_sc^PSCCH(l), a physical-resource-grid quantity;
%                    not computed here -- TS 38.211/+chan/ territory, caller-supplied)
%        gamma       nonnegative integer -- the number of vacant resource elements in the
%                    resource block the last coded 2nd-stage SCI symbol belongs to; inherently
%                    depends on where symbols land once actually mapped to the grid, so this
%                    cannot be derived without RE-mapping -- caller-supplied
%Outputs: G  nonnegative integer -- G^SCI2 = Q'_SCI2 * Qm^SCI2, Qm^SCI2 fixed to 2 (QPSK,
%           confirmed by TS 38.211 clause 8.3.1.2, not stated in 8.4.4 itself)
%
%Two deliberate, independent-verifier-confirmed readings, easy to get backwards:
%  - gamma is added OUTSIDE the min{} of the two ceiling terms, not inside either one -- so G
%    is not bounded by the alpha-scaled RE budget (sumMscSci2=0 with gamma>0 legitimately
%    yields G>0). Clause 8.4.4 does not walk this back.
%  - "A UE is not expected to have G^SCI2 > 4096" is a UE-capability/configuration statement,
%    not a formula clamp. This function does NOT cap G at 4096 -- doing so would silently
%    hide a caller/config bug that produced an over-large value instead of surfacing it.
if ~(OSCI2 >= 0 && mod(OSCI2, 1) == 0)
    error('ts38212:sci2OutputLength:badOSCI2', 'sci2OutputLength: OSCI2 must be a nonnegative integer, got %s', num2str(OSCI2));
end
if ~(betaOffset > 0)
    error('ts38212:sci2OutputLength:badBetaOffset', 'sci2OutputLength: betaOffset must be > 0, got %s', num2str(betaOffset));
end
if ~(R > 0 && R <= 1)
    error('ts38212:sci2OutputLength:badR', 'sci2OutputLength: R must be in (0,1], got %s', num2str(R));
end
if ~(alpha > 0 && alpha <= 1)
    error('ts38212:sci2OutputLength:badAlpha', 'sci2OutputLength: alpha must be in (0,1], got %s', num2str(alpha));
end
LSCI2 = 24;
QmSCI2 = 2;
qBeta = ceil((OSCI2 + LSCI2) * betaOffset / (QmSCI2 * R));
qAlpha = ceil(alpha * sumMscSci2);
QprimeSCI2 = min(qBeta, qAlpha) + gamma;
G = QprimeSCI2 * QmSCI2;
end
