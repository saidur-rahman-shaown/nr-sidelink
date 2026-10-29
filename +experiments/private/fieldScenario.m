function [scen, c, drop] = fieldScenario(f)
%fieldScenario A system-level scenario with UEs dropped as a Poisson point process in a field.
%Inputs: f  struct, every field optional (defaults in brackets):
%   .sizeM        [500 500]  field, metres
%   .densityPerKm2 []        PPP intensity lambda; N ~ Poisson(lambda * area). [] -> use .nUe
%   .nUe          40         a FIXED count, dropped uniformly (a PPP conditioned on N)
%   .dropSeed     7          the placement; independent of .seed (traffic, channel draws)
%   .seed         11
%   .mcs          7          must be a row of the shipped BLER table (assertTableMcs)
%   .prsvpTxMs    100        P_rsvp_TX
%   .numRetx      1          blind retransmissions
%   .castType     'broadcast'
%   .flows        CAM (PQI 58, 100 ms, 300 B) + event (PQI 56 -> 20 ms PDB, Poisson, mean
%                 500 ms, 250 B) -- each a struct as simConfig's c.app.flows
%   .pool         struct of c.pool overrides (simConfig's names)
%   .policy       struct of extra c.policy overrides
%   .txUeIds      []         which UEs generate traffic; [] = every UE
%   .link         struct()   overrides of experiments.settings().link, any subset of: plModel,
%                            losMode, antennaHeightM, antennaGainDb, noiseFigureDb, speedKmh
%Outputs: scen  ready for runLogged
%         c     the simConfig-style config it was built from (for the record)
%         drop  struct: .xy (N x 2) .N .lambda .areaKm2
%
%THE ESCALATION BOUND IS RE-DERIVED FROM THE DROP
%-------------------------------------------------
%scenarioInit derives clause 8.1.4's escalation bound from the CLOSEST separation in the
%deployment (+harness/CLAUDE.md, "maxEscalations was a round 10"). A random drop's closest pair is
%not c.link.spacingM, so the drop is made first and its minimum pairwise distance is what is
%passed in as the spacing; the positions then replace the line scenarioInit lays out.
if nargin < 1, f = struct(); end
d = struct('sizeM', [500 500], 'densityPerKm2', [], 'nUe', 40, 'dropSeed', 7, 'seed', 11, ...
    'mcs', 7, 'prsvpTxMs', 100, 'numRetx', 1, 'castType', 'broadcast', 'pool', struct(), ...
    'policy', struct(), 'txUeIds', [], 'link', struct());
d.flows = struct('pqi', {58, 56}, 'periodMs', {100, 500}, 'sizeBytes', {300, 250}, ...
    'lcid', {4, 5}, 'nPackets', {inf, inf}, 'pdbMsOverride', {[], []}, ...
    'arrival', {'periodic', 'poisson'});
fn = fieldnames(d);
for k = 1:numel(fn)
    if ~isfield(f, fn{k}), f.(fn{k}) = d.(fn{k}); end
end

rs = RandStream('mt19937ar', 'Seed', f.dropSeed);
areaKm2 = prod(f.sizeM) / 1e6;
if ~isempty(f.densityPerKm2)
    % A PPP: a Poisson count, then uniform positions. Drawn by inversion from rs so the whole
    % drop depends on dropSeed alone, never on the global stream.
    N = max(2, poissinv(rand(rs), f.densityPerKm2 * areaKm2));
    lambda = f.densityPerKm2;
else
    N = f.nUe;
    lambda = N / areaKm2;
end
xy =[rand(rs, N, 1) * f.sizeM(1), rand(rs, N, 1) * f.sizeM(2)];
D = sqrt((xy(:, 1) - xy(:, 1)').^2 + (xy(:, 2) - xy(:, 2)').^2);
D(1:N + 1:end) = inf;
dMin = max(1, min(D(:)));

c = simConfig();
c.link.nUe = N; c.link.spacingM = dMin; c.link.txUeIds = f.txUeIds; c.link.castType = f.castType;
c.app = struct('flows', f.flows);
c.policy.mcs = f.mcs; c.policy.prsvpTxMs = f.prsvpTxMs; c.policy.numRetx = f.numRetx;
% numRetx + 1 resources per period must fit sl-MaxNumPerReserve, whose legal values are n2, n3.
c.pool.maxNumPerReserve = max(2, f.numRetx + 1);
% The operating point (experiments.settings().op) first, so a caller's pool override still wins.
op = experiments.settings().op;
c.pool.mu = op.mu; c.pool.numSubchannel = op.numSubchannel; c.pool.subchSizeRb = op.subchSizeRb;
c.radio.pCmaxDbm = op.pCmaxDbm;
c.policy.decodeMarginSlots = op.decodeMarginSlots;   % T2 = PDB - 3 slots (settings.m)
% No TB carries an SDU younger than T_proc,1, on any grant: the 4 ms minimum latency holds for
% packets riding an existing SPS grant too, not only for those that trigger a selection.
c.policy.prepSlots = phy.ts38214.procTimeSelection(op.mu);
% The study's link (settings().link): RMa LOS, 3 m antennas, 3 dBi each, NF 9 dB, and the BLER
% table measured at 20 mph.
lk = experiments.settings().link;
lf = fieldnames(f.link);
for k = 1:numel(lf), lk.(lf{k}) = f.link.(lf{k}); end
c.radio.plModel = lk.plModel; c.radio.losMode = lk.losMode;
c.radio.hTxM = lk.antennaHeightM; c.radio.hRxM = lk.antennaHeightM;
c.radio.antennaGainDb = lk.antennaGainDb; c.radio.noiseFigureDb = lk.noiseFigureDb;
c.radio.speedKmh = round(10 * lk.speedKmh) / 10;
if isfield(f, 'speedKmh') && ~isempty(f.speedKmh), c.radio.speedKmh = round(10 * f.speedKmh) / 10; end
assertTableMcs(f.mcs, c.radio.speedKmh);
pf = fieldnames(f.pool);
for k = 1:numel(pf), c.pool.(pf{k}) = f.pool.(pf{k}); end
pf = fieldnames(f.policy);
for k = 1:numel(pf), c.policy.(pf{k}) = f.policy.(pf{k}); end
c.sim.seed = f.seed; c.sim.plot = false;
scen = harness.sls.scenarioFromConfig(c);
scen.posXY = xy;
drop = struct('xy', xy, 'N', N, 'lambda', lambda, 'areaKm2', areaKm2, 'dMinM', dMin);
end
