function c = amConfig(amRlc, tReassembly, tStatusProhibit)
%amConfig Resolve a sidelink AM RLC configuration into the numeric parameters TS 38.322 uses.
%Spec:   TS 38.331 V16.22.0, SL-RLC-Config-r16 (sl-AM-RLC-r16): sl-SN-FieldLengthAM-r16,
%        sl-T-PollRetransmit-r16, sl-PollPDU-r16, sl-PollByte-r16, sl-MaxRetxThreshold-r16
%        ENUMERATED {t1, t2, t3, t4, t6, t8, t16, t32}; the T-Reassembly, T-StatusProhibit,
%        PollPDU, PollByte and T-PollRetransmit enumerations of clause 6.3.2; and clause 9.1.1.4,
%        where t-Reassembly and t-StatusProhibit are "Selected by the receiving UE, up to UE
%        implementation". TS 38.322 V16.3.0, clauses 7.2, 7.3, 7.4.
%Inputs: amRlc            scalar struct mirroring the ASN.1 leaf:
%                           .sl_SN_FieldLengthAM_r16  char, 'size12' or 'size18'
%                           .sl_T_PollRetransmit_r16  char, e.g. 'ms45'
%                           .sl_PollPDU_r16           char, e.g. 'p4' or 'pInfinity'
%                           .sl_PollByte_r16          char, e.g. 'kB25', 'mB8' or 'infinity'
%                           .sl_MaxRetxThreshold_r16  char, e.g. 't8'
%        tReassembly      char -- a T-Reassembly label. Chosen by the receiving side
%        tStatusProhibit  char -- a T-StatusProhibit label. Chosen by the receiving side
%Outputs: c  scalar struct:
%            .mode              'am'
%            .snFieldLength     integer, 12 or 18
%            .AM_Window_Size    integer, 2048 or 131072 (clause 7.2)
%            .t_PollRetransmit  ms, 5..4000
%            .pollPDU           PDUs, 4..16384, or Inf
%            .pollByte          bytes, 25e3..40e6, or Inf
%            .maxRetxThreshold  integer, 1..32
%            .t_Reassembly      ms, 0..200
%            .t_StatusProhibit  ms, 0..2400
%
%THE TRANSMITTER AND RECEIVER HALVES ARE CONFIGURED BY DIFFERENT UEs
%-------------------------------------------------------------------
%38.331 clause 9.1.1.4 splits the AM parameters by who selects them: t-PollRetransmit, pollPDU,
%pollByte and maxRetxThreshold by the TRANSMITTING UE, t-Reassembly and t-StatusProhibit by the
%RECEIVING UE. SL-RLC-Config-r16 accordingly carries only the first four. One struct holds both
%here because one AM entity has both sides, but a caller modelling two UEs should build each
%peer's struct from its own choices.
%
%pollByte's "kB" is taken as 1000 bytes and "mB" as 10^6 bytes. 38.331 says only "Value kB25
%corresponds to 25 kBytes" and never defines the kilo; see +rlc/CLAUDE.md, pending-human.

SN_LENGTHS = [12 18];
T_POLL_RETRANSMIT_MS = [5:5:250, 300, 350, 400, 450, 500, 800, 1000, 2000, 4000];
POLL_PDU = [4 8 16 32 64 128 256 512 1024 2048 4096 6144 8192 12288 16384];
POLL_BYTE_KB = [25 50 75 100 125 250 375 500 750 1000 1250 1500 2000 3000 4000 ...
                4500 5000 5500 6000 6500 7000 7500];
POLL_BYTE_MB = [8 9 10 11 12 13 14 15 16 17 18 20 25 30 40];
BYTES_PER_KB = 1000;       % pending-human: 38.331 does not define the kilo
BYTES_PER_MB = 1000000;
MAX_RETX = [1 2 3 4 6 8 16 32];
T_REASSEMBLY_MS = [0:5:100, 110:10:200];
T_STATUS_PROHIBIT_MS = [0:5:250, 300, 350, 400, 450, 500, 800, 1000, 1200, 1600, 2000, 2400];

if ~isstruct(amRlc) || ~isfield(amRlc, 'sl_SN_FieldLengthAM_r16') ...
        || ~isfield(amRlc, 'sl_T_PollRetransmit_r16') || ~isfield(amRlc, 'sl_PollPDU_r16') ...
        || ~isfield(amRlc, 'sl_PollByte_r16') || ~isfield(amRlc, 'sl_MaxRetxThreshold_r16')
    error('rlc:amConfig:missingField', ['amConfig: sl_SN_FieldLengthAM_r16, sl_T_PollRetransmit_r16, ' ...
        'sl_PollPDU_r16, sl_PollByte_r16 and sl_MaxRetxThreshold_r16 are all required']);
end

[sn, ok] = resolveLabel(amRlc.sl_SN_FieldLengthAM_r16, 'size', SN_LENGTHS, '');
if ~ok, error('rlc:amConfig:badSnLength', 'amConfig: sl-SN-FieldLengthAM-r16 must be size12 or size18'); end
[tp, ok] = resolveLabel(amRlc.sl_T_PollRetransmit_r16, 'ms', T_POLL_RETRANSMIT_MS, '');
if ~ok, error('rlc:amConfig:badTPollRetransmit', 'amConfig: sl-T-PollRetransmit-r16 is not in T-PollRetransmit'); end
[pp, ok] = resolveLabel(amRlc.sl_PollPDU_r16, 'p', POLL_PDU, 'pInfinity');
if ~ok, error('rlc:amConfig:badPollPDU', 'amConfig: sl-PollPDU-r16 is not in PollPDU'); end
[pbk, okK] = resolveLabel(amRlc.sl_PollByte_r16, 'kB', POLL_BYTE_KB, 'infinity');
[pbm, okM] = resolveLabel(amRlc.sl_PollByte_r16, 'mB', POLL_BYTE_MB, '');
if okK
    pb = pbk * BYTES_PER_KB;
elseif okM
    pb = pbm * BYTES_PER_MB;
else
    error('rlc:amConfig:badPollByte', 'amConfig: sl-PollByte-r16 is not in PollByte');
end
[mr, ok] = resolveLabel(amRlc.sl_MaxRetxThreshold_r16, 't', MAX_RETX, '');
if ~ok, error('rlc:amConfig:badMaxRetx', 'amConfig: sl-MaxRetxThreshold-r16 must be one of t1..t32'); end
[tr, ok] = resolveLabel(tReassembly, 'ms', T_REASSEMBLY_MS, '');
if ~ok, error('rlc:amConfig:badTReassembly', 'amConfig: t-Reassembly label is not in T-Reassembly'); end
[ts, ok] = resolveLabel(tStatusProhibit, 'ms', T_STATUS_PROHIBIT_MS, '');
if ~ok, error('rlc:amConfig:badTStatusProhibit', 'amConfig: t-StatusProhibit label is not in T-StatusProhibit'); end

c = struct( ...
    'mode',             'am', ...
    'snFieldLength',    sn, ...
    'AM_Window_Size',   rlc.windowSize('am', sn), ...
    't_PollRetransmit', tp, ...
    'pollPDU',          pp, ...
    'pollByte',         pb, ...
    'maxRetxThreshold', mr, ...
    't_Reassembly',     tr, ...
    't_StatusProhibit', ts);
end
