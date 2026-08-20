function txt = jsonPair(key, valueJsonText)
%jsonPair One "key":value JSON text fragment, key given verbatim (hyphens and all).
%Spec:   -- (jsonIO boundary helper, not itself a clause of any spec)
%Inputs: key             char, the JSON key exactly as it should appear in the file (this is
%                        how ASN.1-verbatim hyphenated keys reach the output -- MATLAB struct
%                        field names cannot contain hyphens, so encode functions never build
%                        a struct and call jsonencode() on the whole tree; they assemble text
%                        directly, with jsonencode() used only per leaf value below)
%        valueJsonText   char, already-valid JSON text for the value (typically the output of
%                        jsonencode() on a scalar/array leaf, or of jsonJoinObj/jsonJoinArr for
%                        a nested structure)
%Outputs: txt  char, e.g. '"sl-NumSubchannel-r16":5'
txt = ['"' key '":' valueJsonText];
end
