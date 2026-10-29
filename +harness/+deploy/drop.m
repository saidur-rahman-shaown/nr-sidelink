function d = drop(c)
%drop Place and set in motion the UEs of a deployment, and draw each UE's fixed imperfections.
%Inputs: c  deployConfig()
%Outputs: d  struct:
%   .N            number of UEs: Poisson(density x area) when c.ue.densityPerKm2 is set
%   .xy0          N x 2, metres -- positions at t = 0, uniform in the field
%   .vel          N x 2, m/s -- constant velocity; .speedMps N x 1
%   .timingErrS   N x 1, s -- each UE's slot-timing error against the common reference
%   .camOffsetSlots  N x 1 -- each UE's CAM phase (unsynchronised generators)
%Everything is drawn from one stream seeded by c.ue.dropSeed, so a drop is reproducible and is
%independent of c.sim.seed (traffic, noise, fading).
rs = RandStream('mt19937ar', 'Seed', c.ue.dropSeed);
areaKm2 = prod(c.field.sizeM) / 1e6;
if ~isempty(c.ue.densityPerKm2)
    d.N = max(2, poissinv(rand(rs), c.ue.densityPerKm2 * areaKm2));
else
    d.N = c.ue.n;
end
N = d.N;
d.xy0 = [rand(rs, N, 1) * c.field.sizeM(1), rand(rs, N, 1) * c.field.sizeM(2)];
% Fixed positions (c.ue.xy, N x 2 metres) override the drop, e.g. two UEs at a set distance. The
% random draws above still run so the stream, and everything drawn after it, is unchanged.
fixedXy = isfield(c.ue, 'xy') && ~isempty(c.ue.xy);
if fixedXy
    d.N = size(c.ue.xy, 1); N = d.N; d.xy0 = c.ue.xy;
end
v = (c.ue.speedKmh(1) + rand(rs, N, 1) * diff(c.ue.speedKmh)) / 3.6;
if isempty(c.ue.headingDeg)
    hd = rand(rs, N, 1) * 2 * pi;
else
    hd = repmat(deg2rad(c.ue.headingDeg), N, 1);
end
d.vel = [v .* cos(hd), v .* sin(hd)];
d.speedMps = v;
if fixedXy                                    % fixed positions stay put (Doppler: c.radio.dopplerKmh)
    d.vel = zeros(N, 2); d.speedMps = zeros(N, 1);
end
d.timingErrS = (2 * rand(rs, N, 1) - 1) * c.hw.sync.timingErrUs * 1e-6;
slotsPerPeriod = round(c.cam.periodMs * 2);          % mu = 1: 2 slots per ms (asserted by run)
d.camOffsetSlots = floor(rand(rs, N, 1) * slotsPerPeriod);
d.lambdaPerKm2 = N / areaKm2;
end
