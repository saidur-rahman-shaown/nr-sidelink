function test_ReEvalPreemption()
%test_ReEvalPreemption Re-evaluation and pre-emption at T3 = T_proc,1.
%SPEC: TS 38.321 5.22.1.2a; TS 38.214 8.1.4 — checklist items 17, 18

cfg = defaultPreconfig();
nSim = 1500;

%% Item 17 — re-evaluation of a not-yet-signalled resource
% A conflicting reservation appears AFTER selection but BEFORE the first
% SCI; at T3 before the resource, the UE must notice and replace it.
[mac, a1, r1x, ~, ~, seed] = selectWithGap(cfg, nSim);          %#ok<ASGLU>
% inject an SCI whose P=100 projection lands exactly on r1 (log a1+1):
% record at abs a1-200 with matching sub-channels, strong RSRP
mac.db.addRecord(a1 - 200, r1x, 2, 2, 100, -80);
txs = drive(mac, 251, a1 + 1);
assert(mac.stats.reEval >= 1, 'item 17: re-evaluation must fire (seed %d)', seed);
% the original resource must NOT have been transmitted on
hit = arrayfun(@(t) t.absSlot == a1 && t.startSub == r1x, txs);
assert(~any(hit), 'item 17: replaced resource must not be transmitted on');

%% Item 18 — pre-emption of a signalled resource by higher priority
% The retransmission resource r2 is signalled by the initial TX's SCI.
% A higher-priority (prio 1 < own 3) reservation then collides with it.
[mac, a1, ~, a2, r2x] = selectWithGap(cfg, nSim);
txs = drive(mac, 251, a1);                     % initial TX -> r2 signalled
assert(any(arrayfun(@(t) t.absSlot == a1, txs)), 'initial TX expected at a1');
mac.db.addRecord(a2 - 200, r2x, 2, 1, 100, -80);   % prio 1 outranks prio 3
txs = drive(mac, a1 + 1, a2 + 1);
assert(mac.stats.preempt >= 1, 'item 18: pre-emption must fire for prio 1');
hit = arrayfun(@(t) t.absSlot == a2 && t.startSub == r2x, txs);
assert(~any(hit), 'item 18: pre-empted resource must not be transmitted on');

%% Item 18 negative — equal/lower priority must NOT pre-empt
% Same collision but the other SCI has prio 5 (numerically higher = weaker
% than own 3): prio_TX > prio_RX fails, the UE keeps its resource.
[mac, a1, ~, a2, r2x] = selectWithGap(cfg, nSim);
drive(mac, 251, a1);
mac.db.addRecord(a2 - 200, r2x, 2, 5, 100, -80);   % prio 5: weaker
txs = drive(mac, a1 + 1, a2 + 1);
assert(mac.stats.preempt == 0, 'item 18: weaker priority must not pre-empt');
hit = arrayfun(@(t) t.absSlot == a2, txs);
assert(any(hit), 'item 18: resource must be kept and transmitted on');

%% Item 18 — sl-PreemptionEnable absent: no pre-emption at all
cfgOff = cfg;  cfgOff.sl_PreemptionEnable = '';
[mac, a1, ~, a2, r2x] = selectWithGap(cfgOff, nSim);
drive(mac, 251, a1);
mac.db.addRecord(a2 - 200, r2x, 2, 1, 100, -80);   % would qualify otherwise
drive(mac, a1 + 1, a2 + 1);
assert(mac.stats.preempt == 0, 'item 18: absent IE means pre-emption disabled');

fprintf('test_ReEvalPreemption: PASS\n');
end

% ---- helpers ----------------------------------------------------------
function [mac, a1, r1x, a2, r2x, seed] = selectWithGap(cfg, nSim)
% Build a MAC whose first grant has >= 2 resources with a usable gap:
% initial at a1, retransmission at a2, a2 - a1 >= 8 (> T3 + margin).
% Traffic starts at n=250 so the sensing window and injections fit.
for seed = 1:40
    sm = deriveLogicalSlots(cfg, nSim);
    db = SensingDatabase(cfg, sm);
    rs = RandStream('mt19937ar', 'Seed', seed);
    mac = MacEntity(cfg, sm, db, rs);
    mac.hasDataFcn = @(n) n >= 250;
    for a = 50:249, db.markMonitored(a); end       % clean sensing history
    for n = 0:250, mac.runSlot(n); end             % selection at n=250
    g = mac.grant;
    if isempty(g) || size(g.pending, 1) < 2, continue; end
    a1 = sm.logical2abs(g.pending(1, 1));
    a2 = sm.logical2abs(g.pending(2, 1));
    if a2 - a1 >= 8 && a1 >= 258
        r1x = g.pending(1, 2);
        r2x = g.pending(2, 2);
        return;
    end
end
error('selectWithGap:noSeed', 'no seed produced a grant with a usable gap');
end

function txs = drive(mac, n0, n1)
txs = struct('absSlot', {}, 'startSub', {}, 'isInitial', {});
for n = n0:n1
    t = mac.runSlot(n);
    if ~isempty(t)
        txs(end+1) = struct('absSlot', t.absSlot, ...
            'startSub', t.startSub, 'isInitial', t.isInitial); %#ok<AGROW>
    end
end
end
