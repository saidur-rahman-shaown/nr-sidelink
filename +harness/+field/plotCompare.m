function file = plotCompare(rs, labels, outDir, name)
%plotCompare Latency CDFs of several field runs side by side, one panel per flow.
%Spec:   none -- a harness view. Used to show what one UE-implementation knob does to latency
%        with everything else (seed, geometry, traffic, channel) held fixed.
%Inputs: rs      1 x K cell of structs from harness.field.run
%        labels  1 x K cellstr, legend entry per run
%        outDir  char -- output folder (created if absent)
%        name    char -- PNG file name
%Outputs: file  char -- the file written

if ~exist(outDir, 'dir'), mkdir(outDir); end
FLOWS = {'cam', 'denm', 'uni'};
TITLES = {'CAM (PQI 58, PDB 100 ms)', 'DENM (PQI 56, PDB 20 ms)', 'Unicast (PQI 23, PDB 100 ms)'};
f = figure('Visible', 'off', 'Position', [100 100 1350 420], 'Color', 'w');
tl = tiledlayout(f, 1, 3, 'TileSpacing', 'compact');
for k = 1:3
    ax = nexttile(tl); hold(ax, 'on');
    pdb = 0;
    for q = 1:numel(rs)
        r = rs{q};
        P = r.pkt(strcmp({r.pkt.type}, FLOWS{k}));
        lat = [];
        for p = P
            pdb = p.pdbMs;
            hit = r.rx([r.rx.id] == p.id);
            lat = [lat, [hit.rxMs] - p.genMs]; %#ok<AGROW>
        end
        if isempty(lat), continue; end
        v = sort(lat);
        stairs(ax, [0 v], [0 (1:numel(v)) / numel(v)], 'LineWidth', 2, ...
            'DisplayName', sprintf('%s  (median %.1f ms)', labels{q}, median(v)));
    end
    if pdb > 0, xline(ax, pdb, 'k--', 'PDB', 'HandleVisibility', 'off'); xlim(ax, [0 pdb * 1.1]); end
    title(ax, TITLES{k}); xlabel(ax, 'latency (ms)'); ylabel(ax, 'CDF'); grid(ax, 'on');
    legend(ax, 'Location', 'southeast');
end
title(tl, 'Same seed, geometry, traffic and channel; only the Mode-2 selection-window end T2 differs');
file = fullfile(outDir, name);
exportgraphics(f, file, 'Resolution', 150);
close(f);
end
