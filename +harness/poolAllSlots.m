function [physOfLogical, logicalOfPhys, TmaxPrime] = poolAllSlots(mu)
%poolAllSlots The baseline Mode-2 pool: every slot of the DFN period is a sidelink slot.
%Spec:   none itself -- this is a SCENARIO choice, not a procedure. It calls
%        phy.ts38214.poolSlotMap (TS 38.214 V16.17.0, clause 8 preamble) with the inputs that
%        correspond to "everything is sidelink", and asserts the result is what that phrase
%        means. Non-normative, hence +harness/ rather than +phy/.
%Inputs: mu  integer, 0..3 -- mu_SL, the SCS configuration of the SL BWP
%Outputs: physOfLogical  1 x T'max integer -- the identity, 0:10240*2^mu-1
%         logicalOfPhys  1 x 10240*2^mu integer -- also the identity; no entry is -1
%         TmaxPrime      = 10240*2^mu; every slot is in the pool
%
%The three inputs this pins, and why each is the baseline
%--------------------------------------------------------
%  ssbMask   = all false. No slot is excluded for S-SSB. BUILD.md defers S-SSB end-to-end sync
%              explicitly ("an SLS with idealised sync ... is still useful"), so until there is
%              a sync procedure to run there is no reason to reserve slots for it. This is the
%              first of the three to change when sync is built.
%  nonSlMask = all false. Every slot is configured for sidelink. In Mode 2 with no serving cell
%              there is no tdd-UL-DL-ConfigurationCommon taking slots away, which is what makes
%              this the natural default rather than a simplification.
%  bitmap    = all ones, length 10.
%
%WHY THE BITMAP LENGTH IS NOT ARBITRARY
%--------------------------------------
%An all-ones bitmap is not sufficient to get every slot. Clause 8's reserved-slot rule removes
%(L mod L_bitmap) slots BEFORE the bitmap is applied, where L here is the whole DFN period. So
%"all slots" holds only when L_bitmap divides 10240*2^mu = 2^(11+mu) * 5. Of the lengths a
%configuration is likely to carry, 10, 16, 20, 40 and 160 divide it and 11, 12, 30, 50, 60 and
%100 do not -- at L_bitmap = 100 and mu = 1, an all-ones bitmap over a fully-sidelink DFN period
%still loses 80 slots, spread evenly, with nothing anywhere reporting it. Length 10 is chosen as
%the shortest legal value (TS 38.331 SL-ResourcePool-r16, SIZE(10..160)) that divides the period
%at every numerology. The assertion below is what stops a later edit from quietly reintroducing
%the problem.
%
%THE MAP IS THE IDENTITY HERE, AND CALLERS MUST STILL NOT ASSUME IT
%------------------------------------------------------------------
%In this baseline, logical slot i is physical slot i. That makes the conversion free and the
%first end-to-end runs easy to read. It is also exactly the condition under which a caller that
%forgot to convert still produces correct-looking output -- and then breaks the moment a real
%TDD configuration or an S-SSB pattern arrives. Convert through these arrays anyway. The test
%for this function includes a non-identity configuration for that reason.

nDfnSlots = 10240 * 2^mu;
none      = false(1, nDfnSlots);

% Shortest legal sl-TimeResource-r16 that divides 10240*2^mu at every mu; see above.
baselineBitmapLength = 10;
bitmap = true(1, baselineBitmapLength);

[physOfLogical, logicalOfPhys, TmaxPrime] = phy.ts38214.poolSlotMap(mu, none, none, bitmap);

% "Every slot is a sidelink slot" must be literally true, not approximately. If the reserved
% rule removed anything, the bitmap length no longer divides the period.
assert(TmaxPrime == nDfnSlots, ...
    'harness:poolAllSlots:notAllSlots: expected all %d slots in the pool but got %d; L_bitmap = %d does not divide 10240*2^%d', ...
    nDfnSlots, TmaxPrime, baselineBitmapLength, mu);
assert(isequal(physOfLogical, 0:nDfnSlots - 1), ...
    'harness:poolAllSlots:notIdentity: the baseline pool must map logical slot i to physical slot i');
end
