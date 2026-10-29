function file = exportBlerTable(lk, channelLabel)
%exportBlerTable Write a linkCurves measurement into the PHY-abstraction registry
%(+harness/+phyabs/tables/), in harness.phyabs.blerTable's format, so the SLS can read it through
%harness.phyabs.blerTableFor at exactly the channel and speed it was measured under.
%Inputs: lk  from experiments.linkCurves (curves must carry .pscch);  channelLabel  e.g. 'tdld'
%Outputs: file  the .mat written
%Each MCS was measured on its own adaptive SNR grid; the table needs one shared grid, so every curve
%is resampled onto -25:0.5:45 dB by linear interpolation, holding the first measured value below its
%range (BLER 1 there) and the last above it (an error floor stays a floor).
grid = -25:0.5:45;
nM = numel(lk.mcs); nA = size(lk.curve{1}.bler, 2);
tbl.mcs = lk.mcs; tbl.snrDb = grid; tbl.attempt = 1:nA;
tbl.pssch = zeros(nM, numel(grid), nA); tbl.pscch = zeros(nM, numel(grid));
for m = 1:nM
    c = lk.curve{m};
    for a = 1:nA, tbl.pssch(m, :, a) = resample1(c.snrDb, c.bler(:, a), grid); end
    tbl.pscch(m, :) = resample1(c.snrDb, c.pscch, grid);
end
tbl.meta = struct('channelModel', channelLabel, 'speedKmh', round(10 * lk.meta.speedKmh) / 10, ...
    'delaySpreadNs', lk.meta.delaySpreadNs, 'LsubCH', lk.meta.LsubCH, 'nDmrs', lk.meta.nDmrs, ...
    'source', 'experiments.linkCurves (independent channel per TB, DM-RS estimation, ZF, HARQ combining)', ...
    'generated', lk.meta.generated);
d = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), '+harness', '+phyabs', 'tables');
if ~isfolder(d), mkdir(d); end
file = fullfile(d, sprintf('blerTable_%s_%04d.mat', channelLabel, round(10 * lk.meta.speedKmh)));
save(file, 'tbl');
end

function y = resample1(x, v, g)
y = interp1(x(:), v(:), g, 'linear', NaN);
y(g < x(1)) = v(1); y(g > x(end)) = v(end);
end
