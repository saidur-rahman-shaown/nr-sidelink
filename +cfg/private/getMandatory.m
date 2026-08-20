function value = getMandatory(raw, key)
%getMandatory Fetch a JSON-decoded mandatory field; errors, naming the field, if absent.
%Spec:   -- (jsonIO boundary helper, not itself a clause of any spec)
%Inputs: raw  scalar struct produced by jsondecode() for one ASN.1 SEQUENCE
%        key  char, the MATLAB-transliterated field name
%Outputs: value  raw.(key)
%
%A missing mandatory field is a config error, never a silently-applied default -- see the
%"known trap" in +cfg/CLAUDE.md about treating a missing optional as a default in the OOC
%case. By extension a missing *mandatory* field must not default either.
if ~isfield(raw, key)
    error('cfg:jsonDecode:missingField', 'missing mandatory field "%s"', key);
end
value = raw.(key);
end
