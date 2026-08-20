function h = configHash(preconfig)
%configHash Deterministic hash of a resolved preconfig tree, for tagging +vec dumps.
%Spec:   -- (jsonIO boundary helper; +vec/CLAUDE.md requires "a dump file records ... the
%        config hash" so a frozen vector set can be matched back to the config that produced
%        it -- this needs only stability and low accidental-collision risk, not cryptographic
%        strength).
%Inputs: preconfig  scalar struct as returned by cfg.preconfig()
%Outputs: h  char, 8 lowercase hex digits (32-bit DJB2 over the UTF-8 bytes of the canonical
%            JSON encoding -- canonical because cfg.jsonEncode() always emits fields in the
%            same fixed order)
%
%Every intermediate value below stays under 2^32*33 (~1.4e11), well inside a double's exact
%53-bit integer range, so the modular arithmetic is computed exactly in plain double
%arithmetic -- MATLAB's integer classes saturate on overflow rather than wrapping (checked
%directly), so they cannot be used to reproduce the wraparound a C port would get for free
%from an unsigned 32-bit accumulator; this is the portable substitute.
txt = cfg.jsonEncode(preconfig);
bytes = double(unicode2native(txt, 'UTF-8'));
hashVal = 5381;
for i = 1:numel(bytes)
    hashVal = mod(hashVal * 33 + bytes(i), 2^32);
end
h = lower(dec2hex(hashVal, 8));
end
