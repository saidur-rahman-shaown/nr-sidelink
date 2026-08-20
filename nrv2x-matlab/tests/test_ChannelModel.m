function test_ChannelModel()
%test_ChannelModel TR 38.901 RMa distance-based pathloss + channel graph.
%SPEC: 3GPP TR 38.901 Table 7.4.1-1 (RMa); TR 37.885 Annex A reuse for V2X

fc = 5.9e9;

%% RMa LOS hand-computed value at 100 m (h=5 m, equal 1.5 m antennas)
% PL1 = 20log10(40*pi*d*fc_GHz/3) + 0.4778*log10(d) - 0.7009 + 0.002*log10(5)*d
%     = 87.86 + 0.954 - 0.701 + 0.140 = 88.25 dB
[pl, isLOS, sigma] = sidelinkPathLoss(100, fc, 'RMa-LOS');
assert(abs(pl - 88.25) < 0.1, 'RMa LOS @100 m: expected 88.25 dB, got %.2f', pl);
assert(isLOS && sigma == 4, 'RMa LOS: sigma_SF must be 4 dB');

%% monotonic in distance; continuous at the breakpoint
% d_BP = 2*pi*1.5*1.5*fc/c = 278 m
[~, ~, ~, info] = sidelinkPathLoss(100, fc, 'RMa-LOS');
dBP = info.d_BP_m;
assert(abs(dBP - 2*pi*1.5*1.5*fc/3e8) < 1e-6, 'breakpoint distance formula');
plA = sidelinkPathLoss(dBP - 0.5, fc, 'RMa-LOS');
plB = sidelinkPathLoss(dBP + 0.5, fc, 'RMa-LOS');
assert(abs(plB - plA) < 0.2, 'PL must be continuous at the breakpoint');
d = [20 50 100 200 400 800 1600];
pls = arrayfun(@(x) sidelinkPathLoss(x, fc, 'RMa-LOS'), d);
assert(all(diff(pls) > 0), 'pathloss must increase with distance');

%% NLOS >= LOS everywhere (max(PL_LOS, PL_NLOS'))
for dd = [50 200 1000]
    plL = sidelinkPathLoss(dd, fc, 'RMa-LOS');
    [plN, isL, sigN] = sidelinkPathLoss(dd, fc, 'RMa-NLOS');
    assert(plN >= plL, 'NLOS must not beat LOS at %d m', dd);
    assert(~isL && sigN == 8, 'RMa NLOS: sigma_SF must be 8 dB');
end

%% FSPL is the optimistic bound beyond the breakpoint
plF = sidelinkPathLoss(1000, fc, 'FSPL');
plL = sidelinkPathLoss(1000, fc, 'RMa-LOS');
assert(plF < plL, 'FSPL must under-estimate RMa beyond the breakpoint');

%% ChannelGraph: nodes = UEs, edges = channels
g = ChannelGraph(RandStream('mt19937ar', 'Seed', 7));
g.addNode(1, 1048577, [0, 0]);
g.addNode(2, 1048578, [200, 0]);
g.addNode(3, 1048579, [0, 500]);

% reciprocity: the edge is symmetric
assert(abs(g.linkRSRP(1, 2) - g.linkRSRP(2, 1)) < 1e-12, 'reciprocal channel');

% distance ordering survives shadow fading here (seeded draws are small
% relative to the 500 m vs 200 m pathloss difference)
[pl12, sf12, d12] = g.edge(1, 2);
[pl13, ~, d13] = g.edge(1, 3);
assert(d12 == 200 && d13 == 500);
assert(pl13 > pl12, 'longer edge must have more pathloss');
assert(abs(sf12) < 20, 'shadow fading draw must be a plausible dB value');

% link budget: 23 dBm - 94.6 dB - SF ~ -72 dBm at 200 m
r = g.linkRSRP(1, 2);
assert(r > -95 && r < -55, '200 m RMa RSRP out of range: %.1f dBm', r);

% MATLAB graph object view: 3 nodes, full mesh of 3 edges, RSRP weights
G = g.asGraph();
assert(numnodes(G) == 3 && numedges(G) == 3, 'full mesh expected');
assert(all(G.Edges.Weight < -50 & G.Edges.Weight > -150), 'weights are RSRP dBm');

% mobility: moving a node changes pathloss, keeps the edge's SF draw
g.setPosition(2, [400, 0]);
[pl12b, sf12b] = g.edge(1, 2);
assert(pl12b > pl12, 'doubling distance must raise pathloss');
assert(sf12b == sf12, 'static shadow fading draw must persist');

fprintf('test_ChannelModel: PASS\n');
end
