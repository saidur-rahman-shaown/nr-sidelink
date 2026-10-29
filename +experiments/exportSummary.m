function J = exportSummary(s)
%exportSummary Collect every experiment's saved results into <dataRoot>/summary.json.
%Tables become arrays of row objects, so the report (or any other tool) reads one file instead
%of ten .mat files. Experiments that have not been run are simply absent.
if nargin < 1 || isempty(s), s = experiments.settings(); end
names = {'slotStructure', 'sensingSelection', 'rxSensitivity', 'throughputMcs', 'distance', 'rlcSegmentation', ...
    'latency', 'field', 'eventStrategy', 'cbrCapacity', 'waveDeploy'};
J = struct();
for k = 1:numel(names)
    fn = fullfile(s.dataRoot, [names{k} '.mat']);
    if ~isfile(fn), continue; end
    x = load(fn, 'out');
    J.(names{k}) = clean(x.out);
end
J.pdbViolations = clean(experiments.pdbViolations(s));
J.operatingPoint = s.op;
J.generated = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm'));
J.scale = s.scale;
fid = fopen(fullfile(s.dataRoot, 'summary.json'), 'w');
fwrite(fid, jsonencode(J, 'PrettyPrint', true));
fclose(fid);
fprintf('exportSummary: %s\n', fullfile(s.dataRoot, 'summary.json'));
end

function y = clean(x)
%clean Make a value JSON-friendly: tables to row structs, drop function handles and big arrays.
if istable(x) && height(x) > 2000
    % Per-pair raw tables (e.g. the abstraction check's ~1e4 rows) stay in the .mat files; the
    % summary is for the numbers a report quotes.
    y = sprintf('<table, %d rows: see the experiment''s .mat file>', height(x));
elseif istable(x)
    y = table2struct(x);
elseif isstruct(x)
    y = x;
    f = fieldnames(x);
    for k = 1:numel(f)
        if numel(x) == 1
            y.(f{k}) = clean(x.(f{k}));
        end
    end
    if isfield(y, 'scen'), y = rmfield(y, 'scen'); end
    if isfield(y, 'db'), y = rmfield(y, 'db'); end
elseif isnumeric(x) && numel(x) > 2000
    y = sprintf('<%s array, %d elements>', class(x), numel(x));
elseif isa(x, 'function_handle') || isobject(x) && ~isstring(x)
    y = '<object>';
else
    y = x;
end
end
