function test_TwoUEIntegration()
%test_TwoUEIntegration Two SidelinkUEs sharing a pool: sensing avoids overlap.
%
%   UE1 transmits SPS (P=100 ms) from the start. UE2 wakes at slot 300 with
%   a full sensing window, decodes UE1's SCIs at the RSRP given by the
%   TR 38.901 RMa channel graph (200 m rural link, well above the -110 dBm
%   threshold), and must select resources that never overlap UE1's
%   reservation. Also verifies half-duplex bookkeeping, the graph model,
%   and the RF path on a TX slot.

nSim = 1400;
cfg = defaultPreconfig();

ue1 = SidelinkUE(1, cfg, nSim, 41);
ue2 = SidelinkUE(2, cfg, nSim, 42);
ue1.configureTraffic(3, 100, 2, 100);
ue2.configureTraffic(3, 100, 2, 100);
ue2.mac.hasDataFcn = @(n) n >= 300;        % UE2 sleeps until n=300

% deployment: nodes = UEs, edges = RMa channels (Plan.md §11)
g = ChannelGraph(RandStream('mt19937ar', 'Seed', 99));
g.addNode(1, ue1.L2ID, [0, 0]);
g.addNode(2, ue2.L2ID, [200, 0]);          % 200 m rural LOS link
rsrp12 = g.linkRSRP(1, 2);
assert(rsrp12 > -110 && rsrp12 < -60, ...
    'RMa link budget out of expected range: %.1f dBm', rsrp12);
G = g.asGraph();
assert(numnodes(G) == 2 && numedges(G) == 1, 'graph view: 2 nodes, 1 edge');

overlaps = [];
for n = 0:1150
    tx1 = ue1.txPhase(n);                  % two-phase harness (Plan.md §4.3)
    tx2 = ue2.txPhase(n);
    ue1.rxPhase(n, asRx(tx2, ue2.L2ID, g.linkRSRP(2, 1)));
    ue2.rxPhase(n, asRx(tx1, ue1.L2ID, g.linkRSRP(1, 2)));

    if ~isempty(tx1) && ~isempty(tx2) && n >= 420
        lo1 = tx1.startSub; hi1 = lo1 + tx1.LsubCH - 1;
        lo2 = tx2.startSub; hi2 = lo2 + tx2.LsubCH - 1;
        if lo1 <= hi2 && hi1 >= lo2
            overlaps(end+1) = n;           %#ok<AGROW>
        end
    end
end

s1 = ue1.getStats();
s2 = ue2.getStats();

assert(s1.nTx >= 8, 'UE1 must be transmitting SPS (got %d TX)', s1.nTx);
assert(s2.nTx >= 5, 'UE2 must be transmitting after wake-up (got %d TX)', s2.nTx);
assert(s2.selections >= 1, 'UE2 must have run resource selection');
assert(isempty(overlaps), ...
    'sensing must prevent slot+subchannel overlap after warm-up; overlaps at %s', ...
    mat2str(overlaps));

% half-duplex: UE1's own TX slots are unmonitored in its sensing database
for k = 1:min(5, size(ue1.txLog, 1))
    a = ue1.txLog(k, 1);
    lg = ue1.slotMap.abs2logical(a + 1);
    assert(~ue1.db.monitored(lg), 'own TX slot %d must be unmonitored', a);
end
% ...and ordinary listening slots are monitored
quiet = find(~ismember(0:1150, ue1.txLog(:, 1)'), 1, 'last') - 1;
lg = ue1.slotMap.abs2logical(quiet + 1);
assert(ue1.db.monitored(lg), 'listening slots must be monitored');

% RF path on a TX: 23 dBm analog-equivalent waveform out of the UE
[bb, rfSig, rfInfo] = ue1.getWaveform();
assert(~isempty(bb) && ~isempty(rfSig));
assert(abs(rfInfo.AvgPower_dBm - 23) < 1e-9, 'UE RF output must be 23 dBm');

fprintf('test_TwoUEIntegration: PASS (UE1 %d TX, UE2 %d TX, 0 overlaps)\n', ...
    s1.nTx, s2.nTx);
end

% ---- helpers ----------------------------------------------------------
function rx = asRx(tx, srcL2, rsrp_dBm)
if isempty(tx)
    rx = struct([]);
else
    rx = struct('startSub', tx.startSub, 'LsubCH', tx.LsubCH, ...
        'prio', tx.prio, 'Prsvp_ms', tx.Prsvp_ms, ...
        'rsrp_dBm', rsrp_dBm, 'trivLog', tx.trivLog, 'srcL2Id', srcL2);
end
end
