function [kpi, L, ue, scen, resolved] = runLogged(scen, nSlots, opt)
%runLogged harness.sls.runScenario, plus the per-slot record the experiments need.
%Spec:   none -- an experiment driver. It runs the UNCHANGED slot loop (harness.sls.slotStep) and
%        only observes its outputs and the public per-UE state between slots; nothing inside the
%        loop is altered, so a run here and a run through runScenario with the same scenario are
%        the same run.
%Inputs: scen    a prepared scenario (harness.sls.scenarioFromConfig, then edited)
%        nSlots  integer -- physical slots
%        opt     optional struct:
%                 .sampleEverySlots  CBR/CR sampling interval (default 20 = 10 ms at mu=1)
%                 .snapshotSlot      physical slot at which to copy one UE's sensing state
%                                    (default [] = none)
%                 .snapshotUe        which UE (default 1)
%Outputs: kpi       harness.kpiReport's struct
%         L         the log:
%           .air     1 x T struct: .slot .ue .startSubch .LsubCH .rv .prio .pktIds .collided
%                    .sameStart -- every PSSCH transmission. collided = shares the slot and at
%                    least one sub-channel with another; sameStart = its PSCCH landed on another's
%           .rx      struct of row vectors: .slot .txUe .rxUe .ok .distM .air (index into .air)
%           .t       sample times (physical slots); .cbr / .cr  nUe x nSample
%           .sel     1 x S struct: .slot .ue .offsetSlots (first resource - selection slot)
%                    .LsubCH .nRes -- every (re)selection, seen as a change of grant
%           .snapshot  [] or struct: .slot .ue .db .scen -- a copy of one UE's sensing database
%           .nReeval .nPreempt .nCongDrop .nRlf
%         ue, scen, resolved   as runScenario
%
%CBR IS RECOMPUTED HERE, NOT READ FROM ue.cbr
%---------------------------------------------
%The loop updates ue.cbr only when a UE transmits (it is an input to the clause 8.1.6 check), so
%it is stale for a quiet UE. The sample here applies phy.ts38215.cbr to the UE's RSSI window at a
%fixed interval -- the same function, the same window -- so every UE has a time series.

if nargin < 3, opt = struct(); end
assertOperatingPoint(scen);
if ~isfield(opt, 'sampleEverySlots'), opt.sampleEverySlots = 20; end
if ~isfield(opt, 'snapshotSlot'), opt.snapshotSlot = []; end
if ~isfield(opt, 'snapshotUe'), opt.snapshotUe = 1; end

ue = harness.sls.ueInit(1, scen);
for i = 2:scen.nUe
    ue(i) = harness.sls.ueInit(i, scen);
end

resolved = repmat(sap.ctxInit(1, 0, 0, 1, 1, 1, 1, 0, 0), 1, 0);
airC = cell(1, nSlots);
rxC  = cell(1, nSlots);
nS   = floor(nSlots / opt.sampleEverySlots);
L.t   = zeros(1, nS);
L.cbr = nan(scen.nUe, nS);
L.cr  = nan(scen.nUe, nS);
sel = repmat(struct('slot', 0, 'ue', 0, 'offsetSlots', 0, 'LsubCH', 0, 'nRes', 0), 1, 0);
L.snapshot = [];
nTx = 0; nRlf = 0; nReeval = 0; nPreempt = 0; nCong = 0;
airBase = 0;
s = 0;

for n = 0:nSlots - 1
    prevGrant = arrayfun(@(u) grantKey(u.grant), ue, 'UniformOutput', false);
    [ue, scen, done, air, rxLog, rlf, nR, nP, nC] = harness.sls.slotStep(ue, scen, n);
    resolved = [resolved done]; %#ok<AGROW>
    nTx = nTx + numel(air); nRlf = nRlf + rlf; nReeval = nReeval + nR; nPreempt = nPreempt + nP;
    nCong = nCong + nC;

    if ~isempty(air)
        a = struct('slot', n, 'ue', num2cell([air.ueId]), 'startSubch', num2cell([air.startSubch]), ...
            'LsubCH', num2cell([air.LsubCH]), 'rv', num2cell([air.rv]), 'prio', num2cell([air.prioTx]), ...
            'pktIds', {air.ctxIds}, 'collided', false, 'sameStart', false);
        for k = 1:numel(a)
            occ = a(k).startSubch + (0:a(k).LsubCH - 1);
            for q = 1:numel(a)
                if q ~= k && any(ismember(occ, a(q).startSubch + (0:a(q).LsubCH - 1)))
                    a(k).collided = true;
                    a(k).sameStart = a(k).sameStart || a(q).startSubch == a(k).startSubch;
                end
            end
        end
        airC{n + 1} = a;
    end
    % Single precision, one matrix per slot: a 120-UE run logs ~1,200 pairs a slot, and the
    % double-precision version (plus the per-slot concatenation it replaced) ran 10 parallel
    % workers out of memory. single holds slot/UE/air indices exactly up to 2^24.
    if ~isempty(rxLog.ok)
        rxC{n + 1} = single([repmat(n, 1, numel(rxLog.ok)); rxLog.txUe; rxLog.rxUe; double(rxLog.ok); ...
            rxLog.distM; airBase + rxLog.airIdx]);
    end
    airBase = airBase + numel(air);

    for i = 1:scen.nUe
        k = grantKey(ue(i).grant);
        if ue(i).grant.hasGrant && ~isequal(k, prevGrant{i})
            sel(end + 1) = struct('slot', n, 'ue', i, ...
                'offsetSlots', ue(i).grant.txOppSlot(1) - harness.sls.slotToLogical(scen, n), ...
                'LsubCH', ue(i).grant.lSubch, 'nRes', numel(ue(i).grant.txOppSlot)); %#ok<AGROW>
        end
    end

    if mod(n + 1, opt.sampleEverySlots) == 0
        s = s + 1;
        L.t(s) = n;
        for i = 1:scen.nUe
            L.cbr(i, s) = phy.ts38215.cbr(ue(i).rssiWindow, scen.pool.threshSRssiCbrDbm);
            idx = mod(n - (0:scen.crPastSlots - 1), scen.crWindowTotal) + 1;
            L.cr(i, s) = phy.ts38215.cr(sum(ue(i).usedHistory(idx)), 0, scen.numSubchannel, ...
                scen.crPastSlots, scen.crFutureSlots, scen.crWindowTotal);
        end
    end
    if ~isempty(opt.snapshotSlot) && n == opt.snapshotSlot
        L.snapshot = struct('slot', n, 'ue', opt.snapshotUe, 'db', ue(opt.snapshotUe).db, ...
            'nLog', harness.sls.slotToLogical(scen, n), 'scen', scen);
    end
end

airAll = [airC{:}];
if isempty(airAll)
    airAll = struct('slot', {}, 'ue', {}, 'startSubch', {}, 'LsubCH', {}, 'rv', {}, 'prio', {}, ...
        'pktIds', {}, 'collided', {}, 'sameStart', {});
end
L.air = airAll;
R = [rxC{:}];
clear rxC;
if isempty(R), R = zeros(6, 0, 'single'); end
L.rx = struct('slot', double(R(1, :)), 'txUe', double(R(2, :)), 'rxUe', double(R(3, :)), ...
    'ok', R(4, :) == 1, 'distM', R(5, :), 'air', double(R(6, :)));
clear R;
rxDist = double(L.rx.distM); rxOk = L.rx.ok;
L.sel = sel;
L.nReeval = nReeval; L.nPreempt = nPreempt; L.nCongDrop = nCong; L.nRlf = nRlf;
L.nSlots = nSlots;

nGenerated = sum([ue.nextPktId]) - scen.nUe;
cbrByUe = mean(L.cbr, 2, 'omitnan')';
cbrByUe(isnan(cbrByUe)) = 0;
kpi = harness.kpiReport(resolved, nGenerated, nSlots, scen, nTx, rxDist, rxOk, nRlf, ...
    nReeval, nPreempt, nCong, cbrByUe);
kpi.collisionRate = mean([airAll.collided]);
end

function k = grantKey(g)
if g.hasGrant, k = [g.txOppSlot(:); g.txOppStartSubch(:); g.lSubch]'; else, k = []; end
end
