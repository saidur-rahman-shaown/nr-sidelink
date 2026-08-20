function txt = jsonJoinObj(pairs)
%jsonJoinObj Join jsonPair() fragments into one JSON object.
%Spec:   -- (jsonIO boundary helper, not itself a clause of any spec)
%Inputs: pairs  1xN cell array of char, each a jsonPair() fragment (present fields only --
%               an absent OPTIONAL field simply contributes no cell, which is how "omit the
%               key when absent" is implemented on the encode side)
%Outputs: txt  char, e.g. '{"a":1,"b":2}'
txt = ['{' strjoin(pairs, ',') '}'];
end
