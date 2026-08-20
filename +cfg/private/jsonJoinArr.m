function txt = jsonJoinArr(elems)
%jsonJoinArr Join JSON text fragments into one JSON array.
%Spec:   -- (jsonIO boundary helper, not itself a clause of any spec)
%Inputs: elems  1xN cell array of char, each already-valid JSON text for one array element
%Outputs: txt  char, e.g. '[{"a":1},{"a":2}]'
txt = ['[' strjoin(elems, ',') ']'];
end
