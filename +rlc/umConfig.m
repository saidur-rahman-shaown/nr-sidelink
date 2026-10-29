function c = umConfig(umRlc, tReassembly)
%umConfig Resolve a sidelink UM RLC configuration into the numeric parameters TS 38.322 uses.
%Spec:   TS 38.331 V16.22.0, SL-RLC-Config-r16 (sl-UM-RLC-r16) and SL-RLC-ConfigPC5-r16
%        (sl-UM-Bi-Directional-RLC-r16 / sl-UM-Uni-Directional-RLC-r16): SN-FieldLengthUM ::=
%        ENUMERATED {size6, size12}; T-Reassembly ::= ENUMERATED {ms0, ms5, ..., ms100, ms110,
%        ..., ms200}. Clause 9.1.1.5 (STCH): t-Reassembly is "Selected by the receiving UE, up
%        to UE implementation", and for broadcast and groupcast sn-FieldLength is 6.
%        TS 38.322 V16.3.0, clauses 6.2.3.3 and 7.2.
%Inputs: umRlc        scalar struct mirroring the ASN.1 leaf:
%                       .sl_SN_FieldLengthUM_r16  char, 'size6' or 'size12'
%        tReassembly  char -- a T-Reassembly label, e.g. 'ms35'. Taken separately because no
%                     sidelink IE carries it: the RECEIVING UE chooses it (38.331 clause 9.1.1.5)
%Outputs: c  scalar struct:
%            .mode            'um'
%            .snFieldLength   integer, 6 or 12
%            .UM_Window_Size  integer, 32 or 2048 (clause 7.2)
%            .t_Reassembly    ms, 0..200
%
%The SN length is OPTIONAL (Need M) in the ASN.1, but nothing in 38.322 defines an RLC entity
%without one, so an absent field is an error here rather than a silent default.

SN_LENGTHS = [6 12];
T_REASSEMBLY_MS = [0:5:100, 110:10:200];   % T-Reassembly, 38.331 clause 6.3.2

if ~isstruct(umRlc) || ~isfield(umRlc, 'sl_SN_FieldLengthUM_r16')
    error('rlc:umConfig:missingField', 'umConfig: sl_SN_FieldLengthUM_r16 is required');
end
[sn, ok] = resolveLabel(umRlc.sl_SN_FieldLengthUM_r16, 'size', SN_LENGTHS, '');
if ~ok
    error('rlc:umConfig:badSnLength', 'umConfig: sl-SN-FieldLengthUM-r16 must be size6 or size12');
end
[tr, ok] = resolveLabel(tReassembly, 'ms', T_REASSEMBLY_MS, '');
if ~ok
    error('rlc:umConfig:badTReassembly', 'umConfig: t-Reassembly label is not in T-Reassembly');
end

c = struct( ...
    'mode',           'um', ...
    'snFieldLength',  sn, ...
    'UM_Window_Size', rlc.windowSize('um', sn), ...
    't_Reassembly',   tr);
end
