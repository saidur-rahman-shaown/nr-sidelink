function v = viz()
%viz One figure style for every experiment, so the report reads as one document.
%Outputs: v  struct: .cat (8 x 3 categorical RGB, fixed order -- assign series in this order,
%            never cycled), .ink / .muted (text), .grid, .status (good/warn/bad), .seq (a
%            single-hue sequential colormap, light -> dark), .font
%The categorical order is a validated colour-vision-deficiency-safe palette on a light
%surface; past 8 series, fold into "other" or facet rather than generating a new hue.
hex = {'2a78d6', 'eb6834', '1baf7a', 'eda100', 'e87ba4', '008300', '6250d6', 'e34948'};
v.cat = cell2mat(cellfun(@h2r, hex, 'UniformOutput', false)');
v.ink    = h2r('0b0b0b');
v.muted  = h2r('52514e');
v.grid   = [0.85 0.85 0.85];
v.status = struct('good', h2r('1baf7a'), 'warn', h2r('eda100'), 'bad', h2r('e34948'));
lo = [0.92 0.95 0.99]; hi = h2r('0d3a75');
t = linspace(0, 1, 256)';
v.seq  = lo + t .* (hi - lo);
v.font = 11;
end

function rgb = h2r(h)
rgb = [hex2dec(h(1:2)) hex2dec(h(3:4)) hex2dec(h(5:6))] / 255;
end
