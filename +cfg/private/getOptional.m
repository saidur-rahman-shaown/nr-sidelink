function [value, present] = getOptional(raw, key, default)
%getOptional Fetch a JSON-decoded OPTIONAL field with an explicit presence flag.
%Spec:   -- (jsonIO boundary helper, not itself a clause of any spec)
%Inputs: raw      scalar struct produced by jsondecode() for one ASN.1 SEQUENCE
%        key      char, the MATLAB-transliterated field name (jsondecode already turned
%                 the JSON's hyphenated ASN.1 key into this underscore form)
%        default  the dummy value to return when the field is absent
%Outputs: value    raw.(key) if present, else default
%         present  logical, true iff the JSON object carried this key
%
%This file and getMandatory.m/getOptList.m are the only place in +cfg/ that use dynamic
%field-name lookup (raw.(key)). jsondecode() itself hands back a struct whose field set is
%only known at run time, so converting that into the fixed shape the rest of +cfg/ assumes
%is exactly the job of this boundary; nothing outside jsonDecode.m/jsonEncode.m ever calls
%this file, and no other +cfg/*.m file does dynamic field access.
present = isfield(raw, key);
if present
    value = raw.(key);
else
    value = default;
end
end
