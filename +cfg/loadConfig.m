function out = loadConfig(jsonPath, configuredPQIs)
%loadConfig Load, resolve, and validate a sidelink preconfiguration from a JSON file.
%Spec:   TS 38.331 clause 6.3.5, TS 23.287 clause 5.4.4 -- this is the single call site that
%        turns a hand-authored JSON file into the full set of MATLAB objects every other
%        package reads (+cfg/CLAUDE.md build order: jsonIO -> bwpConfig -> resourcePool ->
%        preconfig -> pqiTable -> cfgValidate, all composed here).
%Inputs: jsonPath        char, path to a JSON file (see jsonDecode.m for the expected shape)
%        configuredPQIs  row vector of PQI values actually used by this deployment (optional,
%                        default empty; passed through to cfg.cfgValidate() check 10)
%Outputs: out  scalar struct:
%           specVersions      from cfg.specVersions()
%           preconfig         from cfg.preconfig(), full resolved SidelinkPreconfigNR-r16
%           rrcReconfigSl     1xN struct array from cfg.rrcReconfigSl() (N == 0 if the JSON
%                             file has no "rrcReconfigSl" key)
%           pqiTable          from cfg.pqiTable()
%           numerology        from cfg.bootFromPreconfig(preconfig) (freq 1, BWP 1)
%           configHash        from cfg.configHash(preconfig)
%
%Throws with every diagnostic cfg.cfgValidate() produces (field + clause each) if the config
%does not validate -- this is the B0 gate's "one deliberately broken config is rejected with a
%diagnostic naming the field and the clause."
if nargin < 2, configuredPQIs = zeros(1, 0); end

raw = cfg.jsonDecode(jsonPath);
if ~isfield(raw, 'preconfig')
    error('cfg:loadConfig:missingField', '%s: top-level "preconfig" key is required', jsonPath);
end

out.specVersions = cfg.specVersions();
out.preconfig    = cfg.preconfig(raw.preconfig);

rrcItems = {};
if isfield(raw, 'rrcReconfigSl')
    node = raw.rrcReconfigSl;
    if isa(node, 'cell')
        rrcItems = node(:)';
    elseif isstruct(node)
        rrcItems = num2cell(node(:))';
    end
end
if isempty(rrcItems)
    out.rrcReconfigSl = repmat(struct(), 1, 0);
else
    rc = repmat(cfg.rrcReconfigSl(rrcItems{1}), 1, numel(rrcItems));
    for i = 1:numel(rrcItems)
        rc(i) = cfg.rrcReconfigSl(rrcItems{i});
    end
    out.rrcReconfigSl = rc;
end

out.pqiTable   = cfg.pqiTable();
out.numerology = cfg.bootFromPreconfig(out.preconfig);
out.configHash = cfg.configHash(out.preconfig);

diagnostics = cfg.cfgValidate(out.preconfig, out.pqiTable, configuredPQIs);
if ~isempty(diagnostics)
    lines = cell(1, numel(diagnostics));
    for i = 1:numel(diagnostics)
        lines{i} = sprintf('  [%s] %s (%s): %s', diagnostics(i).path, diagnostics(i).field, ...
            diagnostics(i).clause, diagnostics(i).message);
    end
    error('cfg:loadConfig:invalid', '%s failed validation:\n%s', jsonPath, strjoin(lines, '\n'));
end
end
