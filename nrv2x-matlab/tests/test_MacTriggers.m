function test_MacTriggers()
%test_MacTriggers SPS counter, keep probability, and the seven triggers.
%SPEC: TS 38.321 5.22.1.1 / 5.22.1.2 — checklist items 15, 16

%% SPS persistence + trigger 1 (counter expiry, keep prob = 0)
[mac, sm] = freshMac(1, 4000);
initSlots = driveCollectInitials(mac, 0, 3500);
s = mac.stats;
assert(s.selections >= 2, 'counter expiry with keep=0 must force reselection');
assert(s.triggerCounts(1) >= 1, 'trigger 1 must be counted');
% SPS: within a grant, consecutive initial TX are exactly P'=200 slots apart
d = diff(initSlots);
assert(sum(d == 200) >= 3, 'SPS occurrences must repeat at P''_rsvp_TX=200 slots');
assert(~isempty(sm.logical2abs), 'slot map sanity');

%% trigger 1 keep path: sl-ProbResourceKeep = 1 -> never reselect
cfgKeep = defaultPreconfig();
cfgKeep.sl_ProbResourceKeep = 1.0;
mac = freshMac(2, 4000, cfgKeep);
driveCollectInitials(mac, 0, 3500);
s = mac.stats;
assert(s.keepCount >= 1,          'item 15: keep path must fire at expiry');
assert(s.triggerCounts(1) == 0,   'item 15: keep=1 must never clear the grant');
assert(s.selections == 1,         'item 15: exactly one selection with keep=1');

%% trigger 2: pool (re)configuration
mac = freshMac(3, 4000);
drive(mac, 0, 500);
mac.notifyPoolReconfigured();
drive(mac, 501, 900);
s = mac.stats;
assert(s.triggerCounts(2) == 1 && s.selections == 2, 'trigger 2: clear + reselect');

%% trigger 5: sl-ReselectAfter consecutive unused opportunities
mac = freshMac(4, 4000);
mac.hasDataFcn = @(n) n < 1000;           % traffic stops at 1 s
drive(mac, 0, 2600);
s = mac.stats;
assert(s.triggerCounts(5) >= 1, 'trigger 5: 5 skipped opportunities must reselect');

%% trigger 4: one second without any (re)transmission on the grant
cfg4 = defaultPreconfig();
cfg4.sl_ReselectAfter = [];               % disable trigger 5 to isolate 4
mac = freshMac(5, 8000, cfg4);
mac.hasDataFcn = @(n) n < 1000;
drive(mac, 0, 4000);
s = mac.stats;
assert(s.triggerCounts(4) >= 1, 'trigger 4: 1 s of grant inactivity must clear');

%% triggers 6 and 7: SDU-too-large / PDB-not-met reports
mac = freshMac(6, 4000);
drive(mac, 0, 300);
mac.reportSduTooLarge();
drive(mac, 301, 400);
assert(mac.stats.triggerCounts(6) == 1, 'trigger 6 must clear + reselect');
mac.reportPdbFail();
drive(mac, 401, 500);
assert(mac.stats.triggerCounts(7) == 1, 'trigger 7 must clear + reselect');
assert(mac.stats.selections == 3);

%% trigger 3 is implicit throughout: first selection of every fresh MAC
mac = freshMac(7, 4000);
drive(mac, 0, 10);
assert(mac.stats.triggerCounts(3) == 1 && mac.stats.selections == 1, ...
    'trigger 3: no-grant + data must select');

fprintf('test_MacTriggers: PASS\n');
end

% ---- helpers ----------------------------------------------------------
function [mac, sm] = freshMac(seed, nSim, cfg)
if nargin < 3, cfg = defaultPreconfig(); end
sm = deriveLogicalSlots(cfg, nSim);
db = SensingDatabase(cfg, sm);
rs = RandStream('mt19937ar', 'Seed', seed);
mac = MacEntity(cfg, sm, db, rs);
end

function drive(mac, n0, n1)
for n = n0:n1
    mac.runSlot(n);
end
end

function initSlots = driveCollectInitials(mac, n0, n1)
initSlots = [];
for n = n0:n1
    tx = mac.runSlot(n);
    if ~isempty(tx) && tx.isInitial
        initSlots(end+1) = tx.absSlot;    %#ok<AGROW>
    end
end
end
