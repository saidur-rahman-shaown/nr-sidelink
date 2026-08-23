function g = sci12Multiplex(gSci2, gSlSch, NL, QmSci2)
%sci12Multiplex Multiplex 2nd-stage SCI and SL-SCH coded bits onto a single PSSCH bit sequence.
%Spec:   TS 38.212 V16.15.0, clause 8.2.1 (also serves clause 8.4.5, which cites 8.2.1 directly)
%Inputs: gSci2   column vector (logical or 0/1), length G^SCI2 -- output of sci2ChainEncode
%        gSlSch  column vector (logical or 0/1), length G^SL-SCH -- output of slSchEncode
%        NL      integer, 1 or 2 -- number of layers the SL-SCH transport block is mapped onto.
%                NL=2 is NOT implemented: the spec's own NL=2 procedure writes an explicit
%                placeholder bit ("x") into the second layer's SCI-2 positions and defers its
%                resolution to layer mapping (TS 38.211), which this project has not built --
%                guessing at that placeholder's value would be exactly the kind of unverified
%                assumption this codebase avoids. Revisit once 38.211 layer mapping exists.
%        QmSci2  integer, >=1 -- modulation order of the 2nd-stage SCI (only consulted for
%                NL=2, unused for NL=1)
%Outputs: g  (G^SCI2+G^SL-SCH)-by-1 column vector, logical -- the multiplexed sequence
%           g(0)..g(G-1): NL=1 places all of gSci2 first (g(0..G^SCI2-1)), then all of gSlSch
%           (g(G^SCI2..G-1)) -- clause 8.2.1's NL=1 branch reduces to exactly this concatenation
if NL == 1
    g = [gSci2(:); gSlSch(:)];
elseif NL == 2
    error('ts38212:sci12Multiplex:nl2NotSupported', ...
        'sci12Multiplex: NL=2 is not implemented -- clause 8.2.1''s NL=2 branch defers its placeholder bit to TS 38.211 layer mapping, not built in this project yet');
else
    error('ts38212:sci12Multiplex:badNL', 'sci12Multiplex: NL must be 1 or 2, got %s', num2str(NL));
end
end
