function items = getOptList(raw, key)
%getOptList Fetch a JSON-decoded SEQUENCE-OF field as a uniform cell array of raw elements.
%Spec:   -- (jsonIO boundary helper, not itself a clause of any spec)
%Inputs: raw  scalar struct produced by jsondecode() for the SEQUENCE containing this list
%        key  char, the MATLAB-transliterated field name of the SEQUENCE (SIZE(...)) OF field
%Outputs: items  1xN cell array, each cell a scalar struct for one list element (N == 0 for
%                an absent field or an empty JSON array)
%
%jsondecode() represents a JSON array of objects inconsistently depending on whether the
%objects share an identical field set: a 1-element array decodes to a scalar struct, a
%uniform multi-element array to a struct array, a non-uniform one to a cell array, and an
%empty array to []. Because every element in one of our lists can carry a different subset
%of OPTIONAL keys, any of those four shapes can occur for the same field across different
%configs. This function is the one place that absorbs that ambiguity so every +cfg/*.m
%builder above it always iterates a plain cell array -- see getOptional.m's header for why
%this kind of boundary-layer dynamic behaviour is confined to jsonDecode.m's helpers only.
if ~isfield(raw, key)
    items = {};
    return;
end
node = raw.(key);
if isa(node, 'cell')
    items = node(:)';
elseif isstruct(node)
    items = num2cell(node(:))';
elseif isnumeric(node) && isempty(node)
    items = {};
else
    error('cfg:jsonDecode:badList', '%s: expected a JSON array of objects', key);
end
end
