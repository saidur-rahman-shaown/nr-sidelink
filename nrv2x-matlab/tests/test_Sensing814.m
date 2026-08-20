function test_Sensing814()
%test_Sensing814 TS 38.214 8.1.4 unit tests, keyed to the 20-item checklist
%   in Documentations/Notes/06-Mode2-Sensing-WORKING-REFERENCE.md.
%   Covered here: items 1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13.
%   (14/19 in test_CreselAndProc; 15/16 in test_MacTriggers; 17/18 in
%   test_ReEvalPreemption; 7 is bypassed-by-design [abstract RSRP source];
%   20 is congestion control, not yet implemented.)

cfg = defaultPreconfig();
nSim = 2000;
n = 300;                       % trigger slot; all-pool map => log = abs+1

req0 = struct('n', n, 'LsubCH', 2, 'prioTx', 3, ...
    'remainingPDB_ms', 100, 'PrsvpTx_ms', 100, 'Cresel', 20);

%% Item 1 — sensing window [n-T0, n-Tproc0), right end EXCLUSIVE
[db, sm] = freshDb(cfg, nSim);
markRange(db, 100, 300);
% record AT n-Tproc0 = 299 must be ignored (right end exclusive)
db.addRecord(299, 0, 5, 3, 100, -80);
S_A = selectCandidateResources(req0, cfg, sm, db);
assert(size(S_A, 1) == 196*4, 'item 1: record at n-Tproc0 must be outside window');
% record at 298 IS in the window: occ = log299 + 200 -> abs 498 in [305,500]
db.addRecord(298, 0, 5, 3, 100, -80);
S_A = selectCandidateResources(req0, cfg, sm, db);
assert(size(S_A, 1) == 196*4 - 4, 'item 1: record at n-Tproc0-1 must exclude');

% left edge inclusive: rec at abs 100 (= n-T0) counts, at 99 does not.
[db, sm] = freshDb(cfg, nSim);
markRange(db, 100, 300);
db.addRecord(99, 0, 5, 3, 200, -80);       % P=200: occ -> abs 499, if counted
S_A = selectCandidateResources(req0, cfg, sm, db);
assert(size(S_A, 1) == 196*4, 'item 1: record before n-T0 must be ignored');
db.addRecord(100, 0, 5, 3, 200, -80);      % occ -> log 101+400=501, abs 500
S_A = selectCandidateResources(req0, cfg, sm, db);
assert(size(S_A, 1) == 196*4 - 4, 'item 1: record at n-T0 must be included');

%% Items 3, 4 — selection window T1 = Tproc,1; T2 clamped by PDB
[db, sm] = freshDb(cfg, nSim);
markRange(db, 100, 300);
[S_A, M_total, ~, S_tot] = selectCandidateResources(req0, cfg, sm, db);
absAll = sm.logical2abs(S_tot(:, 1));
assert(min(absAll) == n + 5,   'item 3: window must start at n+T1, T1=Tproc,1=5');
assert(max(absAll) == n + 200, 'item 4: window must end at n+T2 (PDB)');
assert(M_total == 196*4 && size(S_A, 1) == M_total);

reqShort = req0; reqShort.remainingPDB_ms = 10;      % 20 slots < T2min(40)
[~, ~, ~, S_tot] = selectCandidateResources(reqShort, cfg, sm, db);
assert(max(sm.logical2abs(S_tot(:, 1))) == n + 20, ...
    'item 4: T2 = remaining PDB when PDB < T2min');

reqTiny = req0; reqTiny.remainingPDB_ms = 2;         % window collapses
gotErr = false;
try
    selectCandidateResources(reqTiny, cfg, sm, db);
catch e
    gotErr = strcmp(e.identifier, 'sensing:windowEmpty');
end
assert(gotErr, 'item 4: empty selection window must raise, not silently pass');

%% Item 5 — candidates are LOGICAL pool slots only
cfg5 = cfg;  cfg5.sl_TimeResource_r16 = [true false];   % pool = even abs slots
[db5, sm5] = freshDb(cfg5, nSim);
[S_A, M_total] = selectCandidateResources(req0, cfg5, sm5, db5);
absA = sm5.logical2abs(S_A(:, 1));
assert(all(mod(absA, 2) == 0), 'item 5: every candidate must be a pool slot');
assert(M_total == 98*4, 'item 5: M_total counts pool slots only (98 even in window)');

%% Items 2 + 8 — half-duplex slot charged via the HYPOTHETICAL SCI
[db, sm] = freshDb(cfg, nSim);
for a = 100:299
    if a ~= 250, db.markMonitored(a); end   % own TX at 250: unmonitored
end
% hypothetical SCI at log 251 with P=100 (P'=200) -> occ log 451, abs 450
S_A = selectCandidateResources(req0, cfg, sm, db);
assert(~any(S_A(:, 1) == 451), 'items 2/8: projection of unmonitored slot must be excluded');
assert(any(S_A(:, 1) == 452),  'items 2/8: neighbouring slot must survive');
assert(size(S_A, 1) == 196*4 - 4);

%% Item 9 — step 5a re-initialisation when step 5 over-excludes
[db, sm] = freshDb(cfg, nSim);              % NOTHING monitored (boot state)
[S_A, M_total, thOff] = selectCandidateResources(req0, cfg, sm, db);
assert(size(S_A, 1) == M_total && thOff == 0, ...
    'item 9: all-unmonitored boot must re-init S_A, not starve or escalate');

%% Item 6 — 64-entry threshold lookup, i = pRx + (pTx-1)*8
% rec prio 2, own prio 3 -> index 2 + (3-1)*8 = 18
[db, sm] = freshDb(cfg, nSim);
markRange(db, 100, 300);
db.addRecord(250, 1, 1, 2, 100, -100);      % occ -> log 451, subch [1,1]
S_A = selectCandidateResources(req0, cfg, sm, db);
assert(size(S_A, 1) == 196*4 - 2, 'item 6: x=0,1 overlap [1,1] and must go');

cfgB = cfg;  cfgB.sl_Thres_RSRP_List_dBm(18) = -95;   % raise the RIGHT entry
S_A = selectCandidateResources(req0, cfgB, sm, db);
assert(size(S_A, 1) == 196*4, 'item 6: -100 dBm !> -95 dBm, no exclusion');

cfgC = cfg;  cfgC.sl_Thres_RSRP_List_dBm(17) = -95;   % raise a WRONG entry
S_A = selectCandidateResources(req0, cfgC, sm, db);
assert(size(S_A, 1) == 196*4 - 2, 'item 6: unrelated table entry must not matter');

%% Item 10 — two-sided projection: own candidate repeats j = 0..C_resel-1
req10 = req0;  req10.remainingPDB_ms = 250;           % T2=500, Tscal=250 ms
[db, sm] = freshDb(cfg, nSim);
markRange(db, 100, 300);
% sensed P=200 (P'rx=400), m=log251: Q=2 -> occ logs 251, 651, 1051
db.addRecord(250, 0, 5, 3, 200, -80);
S_A = selectCandidateResources(req10, cfg, sm, db);
assert(~any(S_A(:, 1) == 651), 'item 10: direct hit (j=0) excluded');
assert(~any(S_A(:, 1) == 451), ...
    'item 10: y=451 collides at y+1*P''tx=651 — own-side j projection missing');

req10b = req10;  req10b.Cresel = 1;                   % kill the j loop
S_A = selectCandidateResources(req10b, cfg, sm, db);
assert(~any(S_A(:, 1) == 651) && any(S_A(:, 1) == 451), ...
    'item 10: with C_resel=1 only the direct hit may be excluded');

%% Item 11 — Q formula incl. the n'-m <= P'_rsvp_RX guard
req11 = req0;  req11.remainingPDB_ms = 250;
req11.PrsvpTx_ms = 0;  req11.Cresel = 1;              % isolate the sensed side
[db, sm] = freshDb(cfg, nSim);
markRange(db, 100, 300);
% P=20 ms -> P'rx=40; m=log251: n'-m = 301-251 = 50 > 40 -> guard fails, Q=1
db.addRecord(250, 0, 5, 3, 20, -80);
[S_A, M_total] = selectCandidateResources(req11, cfg, sm, db);
assert(size(S_A, 1) == M_total, 'item 11: guard-failed reservation projects once, misses window');
% m=log281: n'-m = 20 <= 40 -> Q = ceil(250/20) = 13 -> 13 window slots hit
db.addRecord(280, 0, 5, 3, 20, -80);
S_A = selectCandidateResources(req11, cfg, sm, db);
assert(~any(S_A(:, 1) == 321), 'item 11: q-projection must reach into the window');
assert(size(S_A, 1) == M_total - 13*4, 'item 11: exactly 13 slots excluded');

%% Item 12 — +3 dB on every pair, restart from step 4, no invented ceiling
req12 = req0;  req12.LsubCH = 5;                      % one candidate per slot
[db, sm] = freshDb(cfg, nSim);
markRange(db, 100, 300);
for a = 105:300                                       % blanket the window
    db.addRecord(a, 0, 5, 3, 100, -80);
end
[S_A, M_total, thOff] = selectCandidateResources(req12, cfg, sm, db);
assert(thOff == 30, 'item 12: -110 needs +30 dB before -80 dBm stops excluding (got +%d)', thOff);
assert(size(S_A, 1) == M_total, 'item 12: after escalation S_A must be re-built from step 4');

%% Item 13 — MAC random selection with equal probability
rs = RandStream('mt19937ar', 'Seed', 11);
S = [(1:10)', zeros(10, 1)];
counts = zeros(10, 1);
for k = 1:5000
    row = MacEntity.pickUniform(S, rs);
    counts(row(1)) = counts(row(1)) + 1;
end
assert(all(counts > 350 & counts < 650), ...
    'item 13: selection must be uniform (counts: %s)', mat2str(counts'));

fprintf('test_Sensing814: PASS\n');
end

% ---- helpers ----------------------------------------------------------
function [db, sm] = freshDb(cfg, nSim)
sm = deriveLogicalSlots(cfg, nSim);
db = SensingDatabase(cfg, sm);
end

function markRange(db, loAbs, hiAbs)
for a = loAbs:hiAbs-1
    db.markMonitored(a);
end
end
