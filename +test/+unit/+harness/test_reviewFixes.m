function test_reviewFixes()
%test_reviewFixes Regressions for the six findings of the 2026-10-26 review (BUGS_TO_ADDRESS.md,
%removed once these passed). Each block is that finding's own reproduction.
%SPEC: none -- harness bookkeeping. Level 1: synthetic inputs with hand-known answers.

%% ---- BUG-03 / BUG-05: deployment verdict per PQI, flow LCID from the QoS mapping ----------
% Two static UEs 50 m apart, defaults CAM = PQI 58 (priority 4, PER 1e-2 -> 99 %) and events =
% PQI 56 (priority 6, PER 1e-1 -> 90 %). The flows' LCIDs come from their SLRBs, whatever the
% priorities are.
c = deployConfig();
assert(c.cam.pqi == 58 && c.evt.pqi == 56, 'the defaults this test is written against');
o = cfg.loadConfig(c.cfgPath, [c.cam.pqi c.evt.pqi]);
k = stack.defaults();
ues = [stack.ueInit(o, 1, c.broadcastL2Id, k, 1), stack.ueInit(o, 2, c.broadcastL2Id, k, 2)];
ues(1) = stack.appSend(ues(1), c.cam.pqi, c.cam.pfi, c.broadcastL2Id, 'broadcast', 1:100, 0);
ues(1) = stack.appSend(ues(1), c.evt.pqi, c.evt.pfi, c.broadcastL2Id, 'broadcast', 1:100, 0);
e = ues(1).ent;
lcCam = e([e.prio] == 4).lcid; lcEvt = e([e.prio] == 6).lcid;
r = struct();
r.c = c; r.c.sim.durationMs = 1000; r.c.sim.rangeM = 300; r.c.field.sizeM = [1000 1000];
r.ues = ues;
r.drop = struct('xy0', [100 100; 150 100], 'vel', zeros(2));
r.nSlots = 2000;
r.rssiDbm = nan(2, r.nSlots, ues(1).g.numSubchannel); r.agc = nan(2, r.nSlots); r.clip = zeros(2, r.nSlots);
mkPkt = @(id, type, genMs, pdbMs) struct('id', id, 'src', 1, 'type', type, 'genMs', genMs, 'dst', 0, 'pdbMs', pdbMs);
mkTx = @(ms, lcid) struct('ue', 1, 'ms', ms, 'startSubch', 0, 'LsubCH', 1, 'prio', 4, 'cast', 1, ...
    'lcids', lcid, 'isRetx', false, 'harqId', 0);
% BUG-05 reproduction: one CAM and one event, both TRANSMITTED in budget, neither delivered, no
% interferer and no half duplex: both losses are RADIO (cause 4), not "not sent" (cause 1).
r.pkt = [mkPkt(1, 'cam', 0, 100), mkPkt(2, 'evt', 200, 20)];
r.txLog = [mkTx(5, lcCam), mkTx(205, lcEvt)];
r.rx = struct('id', {}, 'rxUe', {}, 'rxMs', {});
S = harness.deploy.ueStats(r);
assert(isequal(S.pairs.cause, [4 4]), 'BUG-05: both transmitted-but-undelivered packets are radio losses, got causes %s', mat2str(S.pairs.cause));
% a genuinely unsent packet stays "not sent"
r.txLog = mkTx(5, lcCam);
S = harness.deploy.ueStats(r);
assert(isequal(S.pairs.cause, [4 1]), 'BUG-05: the event never transmitted is not sent, got %s', mat2str(S.pairs.cause));

% BUG-03 reproduction: 20 CAM pairs, 19 on time -> 95 %: FAIL against PQI 58's 99 %.
r.pkt = arrayfun(@(i) mkPkt(i, 'cam', 100 * (i - 1), 100), 1:20);
r.txLog = arrayfun(@(i) mkTx(100 * (i - 1) + 5, lcCam), 1:20);
r.rx = arrayfun(@(i) struct('id', i, 'rxUe', 2, 'rxMs', 100 * (i - 1) + 10), 1:19);
r.c.sim.durationMs = 2000;
S = harness.deploy.ueStats(r);
cam = S.flow(strcmp(S.flow.flow, 'cam'), :);
assert(abs(cam.onTimeShare - 0.95) < 1e-12 && abs(cam.onTimeNeeded - 0.99) < 1e-12 && strcmp(cam.verdict{1}, 'FAIL'), ...
    'BUG-03: PQI 58 at 95 %% must FAIL its 99 %%, got %s at %.2f', cam.verdict{1}, cam.onTimeShare);
evt = S.flow(strcmp(S.flow.flow, 'evt'), :);
assert(strcmp(evt.verdict{1}, 'N/A') && abs(evt.onTimeNeeded - 0.90) < 1e-12, ...
    'BUG-03: no event pairs -> N/A, not PASS; its requirement is PQI 56''s 90 %%');
% 99 of 100 on time is exactly the boundary: PASS
r.pkt = arrayfun(@(i) mkPkt(i, 'cam', 10 * (i - 1), 100), 1:100);
r.txLog = arrayfun(@(i) mkTx(10 * (i - 1) + 5, lcCam), 1:100);
r.rx = arrayfun(@(i) struct('id', i, 'rxUe', 2, 'rxMs', 10 * (i - 1) + 10), 1:99);
S = harness.deploy.ueStats(r);
assert(strcmp(S.flow.verdict{strcmp(S.flow.flow, 'cam')}, 'PASS'), 'BUG-03: 99 %% meets PQI 58''s 99 %% exactly');

%% ---- BUG-04: automatic run length follows the transmitters' actual UE IDs -----------------
cs = simConfig();
cs.sim.plot = false;
cs.link.nUe = 70;
cs.link.txUeIds = 70;
cs.app.flows = cs.app.flows(1);
cs.app.flows(1).nPackets = 1;
[kk, ueS] = runSim(cs);
assert(kk.nGenerated == 1 && ueS(70).flowCount(1) == 1, ...
    'BUG-04: UE 70 alone must generate its one packet (offset 69) before the auto length ends, got %d', kk.nGenerated);

%% ---- BUG-06: system-level bandwidth follows the numerology -------------------------------
for mu = [0 1 2]
    sc = harness.sls.scenarioInit(2, 1, 'broadcast', struct('mu', mu));
    assert(sc.radio.bwHz == sc.nPrb * 12 * 15e3 * 2^mu, 'BUG-06: mu = %d bandwidth %g Hz, expected %g', ...
        mu, sc.radio.bwHz, sc.nPrb * 12 * 15e3 * 2^mu);
end

%% ---- BUG-01: the BLER curve is chosen by the copies a receiver heard, not by the RV -------
% Broadcast, blind retransmission: the receiver's count runs 1 then 2 per TB and never reaches
% 3 (with RV sequence [0 2 3 1], rv + 1 read curve 3 for the second copy).
[~, ueB] = harness.sls.run(10, 600, 3);
cnt = cat(3, ueB.heardCnt);
nRes = harness.sls.scenarioInit(10, 3).maxNumPerReserve;
assert(max(cnt(:)) >= 2 && max(cnt(:)) <= nRes, 'BUG-01: attempts heard per TB must be 1..%d, got max %d', nRes, max(cnt(:)));
% the conditional draw is a probability: B(2)/B(1) in [0, 1] wherever B(1) > 0
tbl = harness.phyabs.blerTable();
b1 = harness.phyabs.blerLookup(7, 1, 1, tbl.meta.channelModel, tbl.meta.speedKmh);
b2 = harness.phyabs.blerLookup(7, 1, 2, tbl.meta.channelModel, tbl.meta.speedKmh);
assert(b2 <= b1 + 1e-12, 'BUG-01: the table is cumulative, B(2) <= B(1)');

fprintf('test_reviewFixes: all assertions passed.\n');
end
