function flag = getFlag(raw, key, expectedLabel)
%getFlag Decode a single-valued OPTIONAL ENUMERATED (the ASN.1 "presence-as-boolean" idiom).
%Spec:   TS 38.331 -- every ENUMERATED with exactly one label (e.g. "ENUMERATED { enabled }",
%        "ENUMERATED { true }") uses ASN.1 presence itself to carry the boolean: the field is
%        included with its one legal label to mean true, omitted to mean false.
%Inputs: raw            scalar struct produced by jsondecode() for the enclosing SEQUENCE
%        key             char, the MATLAB-transliterated field name
%        expectedLabel   char, the single legal ASN.1 label for this field
%Outputs: flag  logical
[label, present] = getOptional(raw, key, '');
if present && ~strcmp(label, expectedLabel)
    error('cfg:jsonDecode:badLabel', '%s: expected label "%s", got "%s"', key, expectedLabel, label);
end
flag = present;
end
