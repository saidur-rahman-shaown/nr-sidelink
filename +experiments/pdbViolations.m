function V = pdbViolations(s)
%pdbViolations Every configuration, in every experiment, where a flow misses its PC5 QoS.
%Spec:   TS 23.287 5.4.4: PDB and PER are a pair, so a flow violates its PDB when the share of
%        packets (per link: per packet-receiver pair) delivered within the PDB is below 1 - PER.
%Inputs: s  optional, experiments.settings()
%Outputs: V  table, one row per violation: experiment, condition, pqi, pdbMs, onTime, target,
%            shortfall (target - onTime, in percentage points), p95Ms (where measured), and the
%            measured context that explains it (collision rate, CBR, distance, SDU size).
%            Also written to <dataRoot>/pdbViolations.csv.
%A row here is a configuration that does NOT meet its delay budget at its reliability target --
%"delivered late" and "never delivered" both count, which is the PER's definition.
if nargin < 1 || isempty(s), s = experiments.settings(); end
d = s.dataRoot;
rows = {};
target = @(pqi) 1 - cfg.pqiLookup(cfg.pqiTable(), pqi).PER;

if isfile(fullfile(d, 'latency.mat'))
    x = load(fullfile(d, 'latency.mat')); o = x.out;
    fn = fieldnames(o.tables);
    for k = 1:numel(fn)
        T = o.tables.(fn{k});
        for r = 1:height(T)
            if T.onTime(r) < T.target(r)
                rows(end + 1, :) = rowOf('latency', sprintf('%s = %g', fn{k}, T.x(r)), T.pqi(r), T.pdbMs(r), ...
                    T.onTime(r), T.target(r), T.p95Ms(r), sprintf('collisions %.0f%%, CBR %.2f', ...
                    100 * T.collisionRate(r), T.cbr(r))); %#ok<AGROW>
            end
        end
    end
    T = o.verdict;
    for r = 1:height(T)
        if ~T.pass(r)
            rows(end + 1, :) = rowOf('latency', ['baseline, ' T.label{r}], T.pqi(r), T.pdbMs(r), ...
                T.achieved(r), T.target(r), NaN, ''); %#ok<AGROW>
        end
    end
end
if isfile(fullfile(d, 'field.mat'))
    x = load(fullfile(d, 'field.mat')); T = x.out.verdict;
    for r = 1:height(T)
        if ~T.pass(r)
            rows(end + 1, :) = rowOf('field', T.label{r}, T.pqi(r), T.pdbMs(r), T.achieved(r), ...
                T.target(r), NaN, sprintf('collisions %.0f%%, CBR %.2f', 100 * x.out.collisions.rate, ...
                x.out.cbr.mean)); %#ok<AGROW>
        end
    end
end
if isfile(fullfile(d, 'eventStrategy.mat'))
    x = load(fullfile(d, 'eventStrategy.mat')); T = x.out.table;
    for r = 1:height(T)
        c = sprintf('%s, %g UE/km^2', T.strategy{r}, T.densityPerKm2(r));
        ctx = sprintf('collisions %.0f%%, CBR %.2f', 100 * T.collisionRate(r), T.cbr(r));
        if T.eventOnTime(r) < target(70)
            rows(end + 1, :) = rowOf('eventStrategy', c, 70, 20, T.eventOnTime(r), target(70), T.eventP95Ms(r), ctx); %#ok<AGROW>
        end
        if T.camOnTime(r) < target(55)
            rows(end + 1, :) = rowOf('eventStrategy', c, 55, 100, T.camOnTime(r), target(55), T.camP95Ms(r), ctx); %#ok<AGROW>
        end
    end
end
if isfile(fullfile(d, 'cbrCapacity.mat'))
    x = load(fullfile(d, 'cbrCapacity.mat')); T = x.out.table;
    for r = 1:height(T)
        if T.onTime(r) < target(55)
            rows(end + 1, :) = rowOf('cbrCapacity', T.load{r}, 55, 100, T.onTime(r), target(55), T.p95LatMs(r), ...
                sprintf('CBR %.2f, collisions %.0f%%', T.cbr(r), 100 * T.collisionRate(r))); %#ok<AGROW>
        end
    end
end
if isfile(fullfile(d, 'distance.mat'))
    x = load(fullfile(d, 'distance.mat')); T = x.out.sls;
    for r = 1:height(T)
        if ismember('infeasible', T.Properties.VariableNames) && T.infeasible(r)
            rows(end + 1, :) = rowOf('distance', sprintf('MCS %d, %s, %g m', T.mcs(r), T.mode{r}, T.dM(r)), ...
                55, 100, 0, target(55), NaN, 'INFEASIBLE: 300 B does not fit the largest TB of this pool'); %#ok<AGROW>
        elseif T.onTime(r) < target(55)
            rows(end + 1, :) = rowOf('distance', sprintf('MCS %d, %s, %g m', T.mcs(r), T.mode{r}, T.dM(r)), ...
                55, 100, T.onTime(r), target(55), T.p95Ms(r), 'range: link budget'); %#ok<AGROW>
        end
    end
end
if isfile(fullfile(d, 'rlcSegmentation.mat'))
    x = load(fullfile(d, 'rlcSegmentation.mat')); T = x.out.table;
    for r = 1:height(T)
        if T.onTime(r) < target(55)
            cap = 'T2 = PDB'; if isfinite(T.t2CapMs(r)), cap = sprintf('T2 cap %g ms', T.t2CapMs(r)); end
            rows(end + 1, :) = rowOf('rlcSegmentation', sprintf('%d B SDU, %g m, %s', T.sduBytes(r), T.dM(r), cap), ...
                55, 100, T.onTime(r), target(55), T.p95Ms(r), sprintf('%.1f segments per SDU', T.newTxPerSdu(r))); %#ok<AGROW>
        end
    end
end
if isfile(fullfile(d, 'waveDeploy.mat'))
    x = load(fullfile(d, 'waveDeploy.mat')); o = x.out;
    for vn = intersect(fieldnames(o)', {'real', 'ideal', 'noReorder'})
        F = o.(vn{1}).flow;
        for r = 1:height(F)
            pq = ifelse(strcmp(F.flow{r}, 'cam'), 55, 70);
            if F.onTimeShare(r) < target(pq)
                rows(end + 1, :) = rowOf('waveDeploy', sprintf('%s hardware variant, %d UEs (waveform level)', vn{1}, o.(vn{1}).N), ...
                    pq, F.pdbMs(r), F.onTimeShare(r), target(pq), F.p95Ms(r), sprintf('%d late, %d lost to collision, %d to radio/hardware', ...
                    F.late(r), F.lostCollision(r), F.lostRadio(r))); %#ok<AGROW>
            end
        end
    end
end
V = cell2table(rows, 'VariableNames', {'experiment', 'condition', 'pqi', 'pdbMs', 'onTime', 'target', ...
    'shortfallPts', 'p95Ms', 'context'});
if ~isempty(V), V = sortrows(V, {'experiment', 'shortfallPts'}, {'ascend', 'descend'}); end
if ~isfolder(d), mkdir(d); end
writetable(V, fullfile(d, 'pdbViolations.csv'));
fprintf('pdbViolations: %d violations -> %s\n', height(V), fullfile(d, 'pdbViolations.csv'));
end

function r = rowOf(e, c, pqi, pdb, on, tgt, p95, ctx)
r = {e, c, pqi, pdb, on, tgt, 100 * (tgt - on), p95, ctx};
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end
