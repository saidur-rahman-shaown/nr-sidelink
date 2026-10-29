function b = rxBufInit()
%rxBufInit Create an empty RLC reception buffer.
%Spec:   TS 38.322 V16.3.0, clauses 5.2.2.2.2 / 5.2.3.2.2 ("place the received UMD/AMD PDU in
%        the reception buffer") and the byte-segment predicates of 5.2.2.2.3, 5.2.3.2.2,
%        5.2.3.2.3 and 5.3.4 that the rxBuf* functions answer.
%Inputs: none
%Outputs: b  scalar struct, flat and serialisable:
%            .sn    1 x K integer -- SN of each stored byte run
%            .so    1 x K integer, 0..65535 -- offset of the run's first byte in its SDU
%            .len   1 x K integer, >=1 -- bytes in the run
%            .last  1 x K logical -- the run contains the SDU's last byte (SI 00 or 10), which
%                   is the only way a receiver learns an SDU's length
%            .data  1 x sum(len) octets -- every run's bytes, concatenated in entry order
%
%One buffer serves both modes because both clauses reason about the same object: which BYTE
%SEGMENTS of SN = x have arrived. Runs never overlap -- rxBufInsert trims what is already held
%(clause 5.2.3.2.2, "discard the duplicate byte segments") -- which is what makes the
%completeness and gap tests simple sums instead of interval arithmetic.
%
%An entity is one buffer. Clause 5.1.1 establishes a receiving entity per (Source Layer-2 ID,
%Destination Layer-2 ID, LCID), so a caller holding one buffer for several peers mixes their
%SN spaces: SN 5 from peer A completes SN 5 from peer B.

b = struct( ...
    'sn',   zeros(1, 0), ...
    'so',   zeros(1, 0), ...
    'len',  zeros(1, 0), ...
    'last', false(1, 0), ...
    'data', zeros(1, 0));
end
