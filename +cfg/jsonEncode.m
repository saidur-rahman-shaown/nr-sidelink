function txt = jsonEncode(preconfig, rrcReconfigList)
%jsonEncode Encode a resolved preconfig (and optional per-link reconfig list) back to JSON.
%Spec:   TS 38.331 clause 6.3.5. Exact inverse of jsonDecode.m + cfg.preconfig()/
%        cfg.rrcReconfigSl() -- round trip through cfg.loadConfig()/cfg.saveConfig() must
%        reproduce the same resolved struct tree (see +cfg/CLAUDE.md interface rule
%        "everything serialises to JSON and reloads bit-identically. Test this.").
%Inputs: preconfig        scalar struct as returned by cfg.preconfig()
%        rrcReconfigList  1xN struct array as returned by cfg.rrcReconfigSl() (optional,
%                         default empty -- the "rrcReconfigSl" key is omitted when empty)
%Outputs: txt  char, JSON text for the whole file: {"preconfig": {...} [, "rrcReconfigSl": [...]]}
if nargin < 2, rrcReconfigList = repmat(struct(), 1, 0); end
pairs = {jsonPair('preconfig', encodePreconfig(preconfig))};
if ~isempty(rrcReconfigList)
    n = numel(rrcReconfigList);
    elems = cell(1, n);
    for i = 1:n
        elems{i} = encodeRrcReconfigSl(rrcReconfigList(i));
    end
    pairs{end+1} = jsonPair('rrcReconfigSl', jsonJoinArr(elems));
end
txt = jsonJoinObj(pairs);
end
