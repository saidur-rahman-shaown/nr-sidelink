function out = slSchEncode(tbBits, R, outlen, rv, modulation, nlayers)
%slSchEncode SL-SCH transport channel processing: CRC, LDPC segmentation/encoding/rate
%matching (stops before clause 8.2.1 multiplexing with SCI-2 -- see sci12Multiplex).
%Spec:   TS 38.212 V16.15.0, clause 8.2 (follows clause 6.2.1-6.2.6, UL-SCH's chain, with
%        I_LBRM fixed to 0 -- "Rate matching of SL-SCH follows the rate matching according to
%        clause 6.2.5 by setting I_LBRM=0"). Modulation scheme restricted per TS 38.211 clause
%        8.3.1.2 Table 8.3.1.2-1 (Supported modulation schemes) -- confirmed against the
%        rendered spec table, not recalled: PSSCH data supports QPSK/16QAM/64QAM/256QAM only,
%        no BPSK of either form (matches the existing restriction already in
%        +phy/+ts38211/slPSSCHConfig.m, independently arrived at there).
%        Toolbox body: nrULSCH. Its own documentation states it implements exactly "Section
%        6.2 Uplink shared channel, Sections 6.2.1 to 6.2.6, without 6.2.7" -- the identical
%        clause range SL-SCH inherits (CRC with automatic 24A/16 polynomial selection per
%        6.2.1, base graph selection per 6.2.2, segmentation per 6.2.3, LDPC encoding per
%        6.2.4, rate matching and concatenation per 6.2.5/6.2.6) -- so this composes nothing
%        by hand; no separate CRC-poly-select/base-graph-select primitives are needed here.
%        LimitedBufferRateMatching defaults to false in the toolbox body, which is exactly
%        I_LBRM=0 -- left at that default, never enabled. Verified bit-identical against the
%        previous hand-composed chain (crcEncode->cbSegment->ldpcEncode->ldpcRateMatch) across
%        both base graphs, both CRC polynomial thresholds (A=3824/3825), 1- and 2-layer
%        transmission, and all four legal modulation schemes before this file was changed.
%
%This function is single-shot and stateless: a fresh nrULSCH object is constructed, loaded
%with tbBits, stepped once, and discarded. It never uses nrULSCH's multi-HARQ-process
%retention feature (persisting a transport block across step calls, indexed by HARQID) --
%HARQ process identity, NDI, and retransmission scheduling are TS 38.321 MAC-layer concerns
%(a future +mac/ package, not built here). That layer decides when to call this function again
%and with which rv/tbBits; this function has no opinion on HARQ process identity.
%Inputs: tbBits      column vector of 0/1 (or logical/int8), length A -- the transport block
%        R           real scalar, 0<R<1 -- code rate indicated by the MCS index (TS 38.214,
%                    not derived here -- caller-supplied; range enforced by nrULSCH itself)
%        outlen      nonnegative integer -- G^SL-SCH, the requested rate-matched (and
%                    concatenated) output length
%        rv          integer, 0..3 -- redundancy version
%        modulation  char, one of 'QPSK','16QAM','64QAM','256QAM' -- Table 8.3.1.2-1
%        nlayers     integer, 1..4 -- number of transmission layers
%Outputs: out  outlen-by-1 column vector, logical -- g^SL-SCH(0)..g^SL-SCH(outlen-1), ready
%              for sci12Multiplex
legalSchemes = {'QPSK', '16QAM', '64QAM', '256QAM'};
if ~ismember(modulation, legalSchemes)
    error('ts38212:slSchEncode:badModulation', 'slSchEncode: "%s" is not in Table 8.3.1.2-1 (QPSK/16QAM/64QAM/256QAM)', modulation);
end
encoder = nrULSCH;
encoder.TargetCodeRate = R;
setTransportBlock(encoder, double(tbBits(:)));
out = logical(encoder(modulation, nlayers, outlen, rv));
end
