function [physOfLogical, logicalOfPhys, TmaxPrime] = poolSlotMap(mu, ssbMask, nonSlMask, bitmap)
%poolSlotMap Slots assigned to a sidelink resource pool, and the logical<->physical mapping.
%Spec:   TS 38.214 V16.17.0, clause 8 preamble ("The set of slots that may belong to a
%        sidelink resource pool is denoted by (t^SL_0, t^SL_1, ..., t^SL_{Tmax-1}) where ...",
%        through "The slots in the set are re-indexed such that the subscripts i of the
%        remaining slots t'^SL_i are successive {0, 1, ..., T'max - 1}"). NOT clause 16.1 of
%        TS 38.213: +phy/+ts38213/CLAUDE.md records that its own module list named a
%        `slotIsInPool` that is "not found in clause 16.1/16.3/16.4's own text", and this is
%        why -- the pool slot set is defined here, in 38.214's clause 8 preamble, alongside
%        the sub-channel definition that +phy/+ts38214/subchannelMap implements.
%Inputs: mu          integer, 0..3 -- mu_SL, the SCS configuration of the SL BWP
%        ssbMask     1 x (10240*2^mu) logical -- true in each of the N_S-SSB slots
%                    "in which S-SS/PSBCH block (S-SSB) is configured". Built by the caller
%                    from phy.ts38213.sSsbSlotIndex over the 16-frame S-SSB period, repeated
%                    across the DFN period; a mask rather than an index list so that a slot
%                    named twice cannot be excluded twice.
%        nonSlMask   1 x (10240*2^mu) logical -- true in each of the N_nonSL slots "in each of which at
%                    least one of Y-th ... (Y+X-1)-th OFDM symbols are not semi-statically
%                    configured as UL", Y = sl-StartSymbol and X = sl-LengthSymbols. Built by
%                    the caller from the TDD configuration (phy.ts38213.slTddConfigDecode, or
%                    tdd-UL-DL-ConfigurationCommon); this function does not decide which
%                    symbols are UL.
%        bitmap      1 x Lbitmap logical -- sl-TimeResource-r16, BIT STRING SIZE(10..160) as
%                    resolved by +cfg/resourcePool.m into sl_TimeResource_r16. b_0 first.
%Outputs: physOfLogical  1 x T'max integer -- physical slot index t'^SL_i of logical slot i.
%                        0-based on both sides: logical slot i is physOfLogical(i+1).
%                        Range 0..10240*2^mu-1.
%         logicalOfPhys  1 x (10240*2^mu) integer -- the inverse: the logical index of slot n
%                        is logicalOfPhys(n+1), or **-1** where slot n is not in the pool.
%                        This is the `slotIsInPool` predicate as well: a slot is in the pool
%                        exactly when its entry is >= 0. Returned rather than searched for, so
%                        both directions are O(1) and provably consistent -- they are built in
%                        one pass, from one array, here.
%         TmaxPrime      positive integer -- T'max, the number of slots in the pool.
%
%A NOTE ON THE SYMBOL T_max, WHICH THIS CLAUSE OVERLOADS
%-------------------------------------------------------
%In the clause, T_max is the size of the set (t^SL_0, ..., t^SL_{T_max-1}) -- the count AFTER
%all three of the S-SSB, non-sidelink and reserved exclusions, but BEFORE the bitmap. The DFN
%period 10240*2^mu is a separate quantity the clause never names; it appears only as the bound
%in "0 <= t^SL_i < 10240 x 2^mu". This function therefore never uses the bare identifier Tmax:
%the DFN period is `nDfnSlots`, the clause's T_max is `numel(tSL)`, and only T'max -- the pool
%size after the bitmap, which the clause does name T'_max -- is returned under a spec symbol.
%Calling the DFN period "Tmax" is the obvious and wrong shorthand; it makes the mask length and
%the clause's T_max look like one quantity when in the worked example they are 10240 and 9140.
%
%THE MAPPING IS APPLIED EXACTLY ONCE, AND THIS IS WHERE
%------------------------------------------------------
%.claude/rules/portability.md requires the logical-to-physical slot mapping be applied once,
%with the other side asserting it does not repeat. This function is that one place. Everything
%in +phy/+ts38214/ downstream of here -- candidateSet, sensingDb*, and clause 8.1.4's whole
%selection window -- is documented as operating on LOGICAL pool slot indices and never
%converting. Callers convert at the boundary by indexing these two arrays and nowhere else.
%
%The four exclusions, in the order the clause states them
%--------------------------------------------------------
%The slot set starts as all 10240*2^mu slots of a DFN period, indexed from slot#0 of the
%radio frame corresponding to DFN 0, and then loses:
%  1. the N_S-SSB S-SSB slots,
%  2. the N_nonSL slots without enough UL symbols,
%  3. N_reserved "reserved slots", spread evenly over what survives 1 and 2, whose only purpose
%     is to make the remaining count an exact multiple of Lbitmap,
%  4. every slot the bitmap does not select.
%Step 3 is the one that is easy to miss and impossible to notice later: without it the bitmap
%phase would slip by (L mod Lbitmap) slots at every DFN wrap, so a pool would drift against its
%own configuration once every 10.24 s. The count it removes is exactly the remainder, which is
%what makes the bitmap tile the survivors evenly, and it is why step 4 can be a plain
%k mod Lbitmap with no correction term.

if ~(mu >= 0 && mu <= 3 && mod(mu, 1) == 0)
    error('ts38214:poolSlotMap:badMu', 'poolSlotMap: mu must be an integer in 0..3, got %s', num2str(mu));
end

% 10240 is the DFN period in subframes (1024 frames x 10 subframes); x2^mu converts to slots.
% Clause 8 preamble, "0 <= t^SL_i < 10240 x 2^mu".
subframesPerDfnPeriod = 10240;
nDfnSlots = subframesPerDfnPeriod * 2^mu;

if ~islogical(ssbMask) || ~isequal(size(ssbMask), [1 nDfnSlots])
    error('ts38214:poolSlotMap:badSsbMask', 'poolSlotMap: ssbMask must be a 1-by-%d logical row vector (10240*2^mu at mu=%d), got size %s', nDfnSlots, mu, mat2str(size(ssbMask)));
end
if ~islogical(nonSlMask) || ~isequal(size(nonSlMask), [1 nDfnSlots])
    error('ts38214:poolSlotMap:badNonSlMask', 'poolSlotMap: nonSlMask must be a 1-by-%d logical row vector (10240*2^mu at mu=%d), got size %s', nDfnSlots, mu, mat2str(size(nonSlMask)));
end
if ~islogical(bitmap) || ~isrow(bitmap)
    error('ts38214:poolSlotMap:badBitmapType', 'poolSlotMap: bitmap must be a logical row vector (sl-TimeResource-r16)');
end
Lbitmap = numel(bitmap);
% TS 38.331 cl. 6.3.5 SL-ResourcePool-r16: sl-TimeResource-r16 is BIT STRING (SIZE (10..160)).
% +cfg/cfgValidate.m checks the same bound; repeated here because this function must not
% silently accept a bitmap that no configuration could have produced.
if Lbitmap < 10 || Lbitmap > 160
    error('ts38214:poolSlotMap:badBitmapLength', 'poolSlotMap: sl-TimeResource-r16 length must be in 10..160, got %d', Lbitmap);
end
if ~any(bitmap)
    error('ts38214:poolSlotMap:emptyBitmap', 'poolSlotMap: sl-TimeResource-r16 selects no slots; the pool would be empty');
end

% ---- exclusions 1 and 2: S-SSB slots and non-sidelink slots ------------------
% "the remaining slots excluding N_S-SSB slots and N_nonSL slots from the set of all the slots
% are denoted by (l_0, l_1, ..., l_{10240*2^mu - N_S-SSB - N_nonSL - 1}) arranged in increasing
% order of slot index."  Physical slot indices are 0-based, MATLAB positions 1-based.
% The clause writes the surviving count as (10240*2^mu - N_S-SSB - N_nonSL), a plain
% subtraction of two counts, which is only equal to the size of the union if the two sets are
% DISJOINT. They are, physically: S-SSB is transmitted in slots configured for sidelink, so an
% S-SSB slot is never a non-sidelink slot. Assert it rather than rely on it -- an overlap would
% make this function's L larger than the clause's expression, shifting N_reserved and every
% index after it, with no other symptom.
if any(ssbMask & nonSlMask)
    error('ts38214:poolSlotMap:maskOverlap', 'poolSlotMap: %d slot(s) are marked both S-SSB and non-sidelink; clause 8''s count (10240*2^mu - N_S-SSB - N_nonSL) presumes these sets are disjoint', nnz(ssbMask & nonSlMask));
end

l = find(~(ssbMask | nonSlMask)) - 1;   % 1 x L, increasing by construction
L = numel(l);
if L == 0
    error('ts38214:poolSlotMap:noSlotsLeft', 'poolSlotMap: every slot is an S-SSB or non-sidelink slot; nothing can belong to a pool');
end

% ---- exclusion 3: the reserved slots ----------------------------------------
% N_reserved = (10240*2^mu - N_S-SSB - N_nonSL) mod L_bitmap, and slot l_r is reserved if
%   r = floor( m * (10240*2^mu - N_S-SSB - N_nonSL) / N_reserved ),  m = 0,1,...,N_reserved-1.
% Read from Documentations/38214-gh0.pdf, not from the reformatted notes: this is a fraction
% inside a floor, and +mac/CLAUDE.md records the same class of formula being rendered with the
% division bar lost. m*L/N_reserved is a PRODUCT over a QUOTIENT, not m*L*N_reserved.
Nreserved = mod(L, Lbitmap);
reservedR = zeros(1, Nreserved);
for m = 0:Nreserved - 1
    reservedR(m + 1) = floor(m * L / Nreserved);   % Nreserved > 0 whenever this loop runs
end
isReserved = false(1, L);
isReserved(reservedR + 1) = true;
tSL = l(~isReserved);                   % 1 x (L - Nreserved), the t^SL_k of the clause

% By construction L - Nreserved is an exact multiple of Lbitmap. Assert it: if it ever fails,
% the reserved-slot arithmetic above is wrong, and every consequence downstream is a silent
% phase slip rather than an error.
assert(mod(numel(tSL), Lbitmap) == 0, ...
    'ts38214:poolSlotMap:reservedCount: after removing %d reserved slots, %d remain, which is not a multiple of L_bitmap=%d', ...
    Nreserved, numel(tSL), Lbitmap);

% ---- exclusion 4: the bitmap ------------------------------------------------
% "a slot t^SL_k belongs to the set if b_k' = 1 where k' = k mod L_bitmap."
k        = 0:numel(tSL) - 1;
selected = bitmap(mod(k, Lbitmap) + 1);
physOfLogical = tSL(selected);          % re-indexed: subscripts are now successive 0..T'max-1
TmaxPrime     = numel(physOfLogical);
if TmaxPrime == 0
    error('ts38214:poolSlotMap:emptyPool', 'poolSlotMap: the bitmap selects no surviving slot; T''max would be 0');
end

% ---- the inverse ------------------------------------------------------------
logicalOfPhys = -ones(1, nDfnSlots);
logicalOfPhys(physOfLogical + 1) = 0:TmaxPrime - 1;
end
