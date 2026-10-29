function [f, ax] = newFig(widthPx, heightPx, nRows, nCols)
%newFig A figure with the shared style; tiled when nRows/nCols are given.
%Invisible, so a batch run never steals focus; saveFig writes it out.
if nargin < 1, widthPx = 820; end
if nargin < 2, heightPx = 480; end
tiled = nargin >= 3;
if nargin < 4, nCols = 1; end
v = viz();
f = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 widthPx heightPx]);
set(f, 'DefaultAxesFontSize', v.font, 'DefaultAxesXColor', v.muted, ...
    'DefaultAxesYColor', v.muted, 'DefaultAxesGridColor', v.grid, 'DefaultAxesGridAlpha', 1, ...
    'DefaultLineLineWidth', 2, 'DefaultAxesColorOrder', v.cat, 'DefaultTextColor', v.ink, ...
    'DefaultAxesBox', 'off', 'DefaultAxesTickDir', 'out');
if tiled
    ax = tiledlayout(f, nRows, nCols, 'TileSpacing', 'compact', 'Padding', 'compact');
else
    ax = axes(f);
    hold(ax, 'on'); grid(ax, 'on');
end
end
