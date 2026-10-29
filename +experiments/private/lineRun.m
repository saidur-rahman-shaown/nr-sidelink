function S = lineRun(dM, mode, mcs, seed, nSlots, flow)
%lineRun One transmitter, one receiver at distance dM, through the full SLS: latency and PRR.
%Inputs: dM     separation, metres
%        mode   'none'     broadcast, one transmission per TB (numRetx 0)
%               'blind1'   broadcast, one blind retransmission (numRetx 1, the default)
%               'feedback' unicast, PSFCH HARQ-ACK: a NACK/DTX releases the next resource, an ACK
%                          stops; PSFCH symbols shrink every TBS in the pool (clause 8.1.3.2)
%        mcs    a row of the shipped BLER table
%        seed, nSlots
%        flow   simConfig-style flow struct (default PQI 58, 50 ms, 300 B)
%Outputs: S  struct: .d .mode .mcs .onTime (per packet, delivered within PDB) .latMs (delivered)
%            .txPerDelivery .linkPrr (per decode attempt at the receiver) .nPkt
if nargin < 6 || isempty(flow)
    flow = struct('pqi', 58, 'periodMs', 50, 'sizeBytes', 300, 'lcid', 4, 'nPackets', inf, ...
        'pdbMsOverride', [], 'arrival', 'periodic');
end
c = simConfig();
c.link.nUe = 2; c.link.spacingM = dM; c.link.txUeIds = 1;
c.app = struct('flows', flow);
c.policy.mcs = mcs; c.policy.prsvpTxMs = flow.periodMs;
op = experiments.settings().op;
c.pool.mu = op.mu; c.pool.numSubchannel = op.numSubchannel; c.pool.subchSizeRb = op.subchSizeRb;
c.radio.pCmaxDbm = op.pCmaxDbm; c.policy.decodeMarginSlots = op.decodeMarginSlots; c.policy.prepSlots = phy.ts38214.procTimeSelection(op.mu);
lk = experiments.settings().link;
c.radio.plModel = op.plModel; c.radio.losMode = lk.losMode; c.radio.antennaGainDb = lk.antennaGainDb;
c.radio.hTxM = lk.antennaHeightM; c.radio.hRxM = lk.antennaHeightM; c.radio.noiseFigureDb = lk.noiseFigureDb;
c.radio.speedKmh = round(10 * lk.speedKmh) / 10;
assertTableMcs(mcs, c.radio.speedKmh);
switch mode
    case 'none',     c.link.castType = 'broadcast'; c.policy.numRetx = 0;
    case 'blind1',   c.link.castType = 'broadcast'; c.policy.numRetx = 1;
    case 'feedback', c.link.castType = 'unicast';   c.policy.numRetx = 1;
    otherwise, error('experiments:lineRun:mode', 'unknown mode %s', mode);
end
c.sim.seed = seed; c.sim.plot = false;
S.d = dM; S.mode = mode; S.mcs = mcs;
try
    scen = harness.sls.scenarioFromConfig(c);
catch e
    % The payload does not fit the largest transport block this (MCS, PSFCH) pool offers -- at
    % 50 PRB, MCS 4 with PSFCH tops out at 233 B. A physical limit of the operating point, recorded
    % as INFEASIBLE rather than as a crash or a silent omission.
    if ~any(strcmp(e.identifier, {'sls:scenarioInit:probeTooSmall', 'sls:scenarioInit:sduTooLarge'}))
        rethrow(e);
    end
    S.infeasible = true; S.onTime = false(1, 0); S.latMs = zeros(1, 0);
    S.txPerDelivery = NaN; S.linkPrr = NaN; S.nPkt = 0; S.tbsBytesMax = NaN;
    return;
end
S.infeasible = false;
[kpi, L, ~, scen, res] = runLogged(scen, nSlots);
codes = sap.outcomeCodes();
msPerSlot = 1 / 2^scen.mu;
pdb = scen.flows(1).pdbMs;
keep = double([res.tGenSlot]) + pdb / msPerSlot < nSlots;
res = res(keep);
del = [res.outcome] == codes.delivered;
lat = double([res.tRxSlot] - [res.tGenSlot]) * msPerSlot;
S.onTime = del & lat <= pdb;
S.latMs = lat(del);
S.txPerDelivery = kpi.txPerDelivery;
rx2 = L.rx.rxUe == 2;
S.linkPrr = mean(L.rx.ok(rx2));
S.nPkt = numel(res);
S.tbsBytesMax = scen.maxTbsBytes;
end
