function R = sweep(cfgs, nSlots, s, rangeM)
%sweep Run every (config, seed) point of a system-level sweep, in parallel when available.
%Inputs: cfgs    1 x C cell of fieldScenario override structs
%        nSlots  physical slots per run
%        s       experiments.settings() -- .seeds and .useParallel are read
%        rangeM  intended-receiver range for the per-link statistics
%Outputs: R  C x nSeed cell of summarizeRun structs
%Each point is independent and seeded by its own config, so parfor changes nothing but the
%wall clock: the seed is written into the config BEFORE dispatch, never drawn on a worker.
seeds = s.seeds;
nC = numel(cfgs); nS = numel(seeds);
jobs = cell(1, nC * nS);
for c = 1:nC
    for k = 1:nS
        f = cfgs{c};
        f.seed = seeds(k);
        if ~isfield(f, 'dropSeed'), f.dropSeed = seeds(k) + 1000; end
        jobs{(c - 1) * nS + k} = f;
    end
end
out = cell(1, numel(jobs));
if s.useParallel
    if isempty(gcp('nocreate')), parpool('Processes', s.nWorkers); end
    parfor j = 1:numel(jobs)
        out{j} = runOne(jobs{j}, nSlots, rangeM);
    end
else
    for j = 1:numel(jobs)
        out{j} = runOne(jobs{j}, nSlots, rangeM);
    end
end
R = reshape(out, nS, nC)';
end

function S = runOne(f, nSlots, rangeM)
scen = fieldScenario(f);
[kpi, L, ~, scen, res] = runLogged(scen, nSlots);
S = summarizeRun(kpi, L, res, scen, rangeM);
S.cfg = f;
end
