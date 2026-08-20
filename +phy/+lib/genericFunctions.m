%% Generic MATLAB (5G Toolbox) functions -- reference catalog, not a module
%
% Not executable code, not a wrapper. Toolbox call syntax appears in comments only
% for reference -- fine here since +phy/+lib/ is the one package the toolbox-call
% ban (.claude/rules/normative-packages.md) does not apply to. When a normative
% package actually needs one of these, it goes behind a real +phy/+lib/ wrapper
% per +phy/+lib/CLAUDE.md "Toolbox first" -- this file is the lookup list that
% precedes writing that wrapper, and grows as more clauses get surveyed.

%% TS 38.211 chapter 5 -- general functions

% nrSymbolModulate -- Sec 5.1, modulation mapper
%   out = nrSymbolModulate(in, mod)
%   in:  column vector of bits
%   mod: 'pi/2-BPSK' | 'BPSK' | 'QPSK' | '16QAM' | '64QAM' | '256QAM'
%   out: column vector of complex symbols, unit average power

% nrPRBS -- Sec 5.2.1, pseudo-random (Gold) sequence generator, c(n)
%   [seq, cinit] = nrPRBS(cinit, n)
%   cinit: integer 0..2^31-1
%   n:     element count, or [p m] to return c(p)..c(p+m-1)
%   seq:   logical (default) or numeric column vector; 'MappingType' 'binary'|'signed'
%   Nc=1600 offset is applied internally -- verified against a hand-rolled LFSR.

% nrLowPAPRS -- Sec 5.2.2, low-PAPR type-1 sequences, ALL lengths in one call form
%   seq = nrLowPAPRS(u, v, alpha, m)
%   u:     sequence group number, 0..29
%   v:     base sequence number, 0 or 1 (must be 0 when m < 72)
%   alpha: cyclic shift, radians
%   m:     sequence length (internally: phase-table for m<30, cyclic-extended
%          Zadoff-Chu for m>=30 -- both branches live inside this one call form)
%
%   nrLowPAPRS(u, cinit, m) is a DIFFERENT sequence family (TS 38.211 clause
%   5.2.3, "type 2", for Rel-16 DM-RS transform precoding on PUSCH/PUCCH) --
%   not constant modulus, not a short-length variant of the above. Confirmed by
%   running both forms; do not conflate them.
