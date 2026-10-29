function r = run(c)
%run A waveform-level field scenario: N UEs, real traffic, every packet through the full stack.
%Spec:   none -- a harness. The UEs are +stack/ (every 3GPP layer, configured from c.cfgPath); this
%        function only moves the UEs, generates the application traffic, and is the radio
%        channel between them: per directed link, path loss (harness.chanmodel.pathloss, TR 38.901
%        RMa) and optional TDL fading (harness.chanmodel.tdlChannel), all transmitters summed at
%        each receiver (so collisions and interference are physical), plus thermal noise
%        (rf.noiseFloorDbm). Half duplex is the stack's (stack.rxSlot).
%Inputs: c  struct from fieldConfig
%Outputs: r  scalar struct:
%            .pkt   1 x P struct array, every application packet generated:
%                   .id .src (UE index) .type ('cam'|'denm'|'uni') .genMs .dst (UE index or 0 for
%                   broadcast) .pdbMs
%            .rx    1 x D struct array, every delivery: .id .rxUe .rxMs .bytes
%            .txLog 1 x T struct array, every PSSCH transmission: .ue .ms .startSubch .LsubCH
%                   .prio .cast .lcids .isRetx .harqId (the resource-occupancy record)
%            .rxLog 1 x R struct array, every PSCCH some UE decoded: .ue .ms .startSubch .LsubCH
%                   .sourceID .tbOk (stand-alone, before combining) .rsrpDbm -- with txLog, the
%                   collision and capture record (harness.field.collisions)
%            .pointAHz  the preconfiguration's sl-AbsoluteFrequencyPointA as a frequency -- printed
%                   beside c.radio.fcHz, because the channel is evaluated at the latter
%            .ues   the final UE structs (stats, entities)
%            .linkSnrDb  N x N, the mean per-RE SNR of a 10-PRB transmission over each link at
%                   t = 0 (path loss only), for the report
%            .c     the config
%
%LATENCY IS MEASURED FROM THE APPLICATION'S CLOCK. Each payload starts with an 8-byte application
%header (packet id, message type, originating UE) -- the way an ITS PDU header identifies a
%message -- so a receiver's delivery can be matched to its generation time without reading any
%layer's internal state (docs/INTEGRATION.md: KPIs close on application timestamps).

o = cfg.loadConfig(c.cfgPath, [c.cam.pqi c.denm.pqi c.uni.pqi]);
k = stack.defaults();
k.noiseFigureDb = c.radio.noiseFigureDb;
k.tReorderingMs = c.impl.tReorderingMs;
k.t2MaxMs = c.impl.t2MaxMs;
if isfield(c.impl, 'gcbcRxOutOfOrder'), k.gcbcRxOutOfOrder = c.impl.gcbcRxOutOfOrder; end
N = numel(c.ue.x);
ues = repmat(stack.ueInit(o, c.ue.l2Id(1), c.broadcastL2Id, k, c.sim.seed), 1, N);
for u = 2:N
    ues(u) = stack.ueInit(o, c.ue.l2Id(u), c.broadcastL2Id, k, c.sim.seed + u);
end
[ues(c.uni.from), ues(c.uni.to)] = stack.unicastSetup(ues(c.uni.from), ues(c.uni.to));
g = ues(1).g;
slotMs = g.slotMs;
% Run length from a PACKET COUNT when no duration is given: c.sim.nPackets CAMs in total over the
% N UEs (each UE at least ceil(nPackets / N)), one period for the per-UE phases, and the longest
% PDB in use so the last packets resolve before the end.
camQuota = inf;                        % CAMs per UE; finite only when the run is sized by count
if isempty(c.sim.durationMs)
    camQuota = ceil(c.sim.nPackets / N);
    pq0 = cfg.pqiTable();
    maxPdbMs = max(arrayfun(@(q) cfg.pqiLookup(pq0, q).PDB_ms, [c.cam.pqi c.denm.pqi c.uni.pqi]));
    c.sim.durationMs = (ceil(c.sim.nPackets / N) + 1) * c.cam.periodMs + maxPdbMs;
    fprintf('field: %d CAMs over %d UEs -> %.1f s of air time\n', c.sim.nPackets, N, c.sim.durationMs / 1000);
end
nSlots = round(c.sim.durationMs / slotMs);
rs = RandStream('mt19937ar', 'Seed', c.sim.seed);

% ---- channel: path loss model, per-link fading objects, noise --------------------
plModel = harness.chanmodel.pathlossModel(c.radio.plModel, struct('fcHz', c.radio.fcHz, ...
    'losMode', c.radio.losMode, 'hTxM', c.radio.hAntM, 'hRxM', c.radio.hAntM));
[~, fs] = phy.lib.ofdmMod(complex(zeros(g.nSubcarriers, g.NsymbSlot)), g.mu, 0);
noiseVarW = 10^(rf.noiseFloorDbm(fs, c.radio.noiseFigureDb) / 10) / 1000;   % per sample
fade = cell(N, N);
if ~isempty(c.radio.fading)
    for i = 1:N
        for j = 1:N
            if i ~= j
                % Double mobility: both ends move against static scatterers, so the maximum
                % Doppler is (|v_i| + |v_j|) / lambda -- NOT the relative speed, which would leave
                % two cars in convoy (relative speed ~0) with a frozen channel they do not have.
                dopKmh = (abs(c.ue.vMps(i)) + abs(c.ue.vMps(j))) * 3.6;
                fade{i, j} = harness.chanmodel.tdlChannel(c.radio.fading, c.radio.delaySpreadNs, ...
                    dopKmh, c.radio.fcHz, fs, c.sim.seed * 100 + i * 10 + j);
            end
        end
    end
end

% ---- traffic schedule -------------------------------------------------------------
pkt = repmat(struct('id', 0, 'src', 0, 'type', '', 'genMs', 0, 'dst', 0, 'pdbMs', 0), 1, 0);
camOffsetMs = floor(rand(rs, 1, N) * c.cam.periodMs / slotMs) * slotMs;   % unsynchronised CAMs
camSent = zeros(1, N);
pqi = cfg.pqiTable();
rx = repmat(struct('id', 0, 'rxUe', 0, 'rxMs', 0, 'bytes', 0), 1, 0);
rxLog = repmat(struct('ue', 0, 'ms', 0, 'startSubch', 0, 'LsubCH', 0, 'sourceID', -1, 'tbOk', false, ...
    'rsrpDbm', 0), 1, 0);
txLog = repmat(struct('ue', 0, 'ms', 0, 'startSubch', 0, 'LsubCH', 0, 'prio', 0, 'cast', 0, ...
    'lcids', zeros(1, 0), 'isRetx', false, 'harqId', 0), 1, 0);

for n = 0:nSlots - 1
    tMs = n * slotMs;
    % ---- applications ------------------------------------------------------------
    for u = 1:N
        if mod(tMs - camOffsetMs(u), c.cam.periodMs) == 0 && tMs >= camOffsetMs(u) && camSent(u) < camQuota
            camSent(u) = camSent(u) + 1;
            [ues(u), pkt] = send(ues(u), pkt, u, 'cam', c.cam, c.broadcastL2Id, 'broadcast', 0, tMs, pqi);
        end
    end
    tD = tMs - c.denm.startMs;
    if tD >= 0 && mod(tD, c.denm.repetitionMs) == 0 && tD / c.denm.repetitionMs < c.denm.count
        u = c.denm.ueIdx;
        [ues(u), pkt] = send(ues(u), pkt, u, 'denm', c.denm, c.broadcastL2Id, 'broadcast', 0, tMs, pqi);
    end
    if tMs >= c.uni.startMs && mod(tMs - c.uni.startMs, c.uni.periodMs) == 0
        u = c.uni.from;
        [ues(u), pkt] = send(ues(u), pkt, u, 'uni', c.uni, c.ue.l2Id(c.uni.to), 'unicast', c.uni.to, tMs, pqi);
    end

    % ---- every UE transmits (or not) ----------------------------------------------
    iqs = cell(1, N);
    for u = 1:N
        [ues(u), iqs{u}, tx] = stack.txSlot(ues(u), n);
        if ~isempty(tx)
            txLog(end + 1) = struct('ue', u, 'ms', tMs, 'startSubch', tx.startSubch, 'LsubCH', tx.LsubCH, ...
                'prio', tx.prio, 'cast', tx.cast, 'lcids', tx.lcids, 'isRetx', tx.isRetx, 'harqId', tx.harqId); %#ok<AGROW>
        end
    end
    % ---- the channel, and every UE receives -----------------------------------------
    pos = [c.ue.x(:) + c.ue.vMps(:) * tMs / 1000, c.ue.y(:)];
    for j = 1:N
        y = [];
        for i = 1:N
            if i == j || isempty(iqs{i}), continue; end
            d = hypot(pos(i, 1) - pos(j, 1), pos(i, 2) - pos(j, 2));
            x = iqs{i} * 10^(-harness.chanmodel.pathloss(plModel, d) / 20);
            if ~isempty(fade{i, j})
                x = applyFading(fade{i, j}, x, tMs / 1000);
            end
            if isempty(y), y = x; else, y = y + x; end
        end
        if ~isempty(y)
            y = y + sqrt(noiseVarW / 2) * (randn(rs, size(y)) + 1j * randn(rs, size(y)));
        end
        [ues(j), out, dec] = stack.rxSlot(ues(j), y, n);
        for q = 1:numel(dec)
            rxLog(end + 1) = struct('ue', j, 'ms', tMs, 'startSubch', dec(q).startSubch, ...
                'LsubCH', dec(q).LsubCH, 'sourceID', dec(q).sourceID, 'tbOk', dec(q).tbOk, ...
                'rsrpDbm', dec(q).rsrpDbm); %#ok<AGROW>
        end
        for q = 1:numel(out)
            p = out(q).payload;
            id = p(1) * 2^24 + p(2) * 2^16 + p(3) * 2^8 + p(4);
            rx(end + 1) = struct('id', id, 'rxUe', j, 'rxMs', tMs, 'bytes', numel(p)); %#ok<AGROW>
        end
    end
end

% ---- per-link SNR at t = 0 (a 10-PRB transmission at P_CMAX), for the report -------------
SUBCARRIERS = 10 * 12;
noisePerReDbm = rf.noiseFloorDbm(15e3 * 2^g.mu, c.radio.noiseFigureDb);
linkSnrDb = nan(N);
for i = 1:N
    for j = 1:N
        if i ~= j
            d = hypot(c.ue.x(i) - c.ue.x(j), c.ue.y(i) - c.ue.y(j));
            linkSnrDb(i, j) = k.pCmaxDbm - 10 * log10(SUBCARRIERS) - harness.chanmodel.pathloss(plModel, d) - noisePerReDbm;
        end
    end
end
pointAHz = arfcnToHz(o.preconfig.sl_PreconfigFreqInfoList_r16(1).sl_AbsoluteFrequencyPointA_r16);
r = struct('pkt', pkt, 'rx', rx, 'txLog', txLog, 'rxLog', rxLog, 'pointAHz', pointAHz, 'ues', ues, 'linkSnrDb', linkSnrDb, 'c', c);
end

% =========================================================================================
function [ue, pkt] = send(ue, pkt, u, type, flow, dstL2, castLbl, dstIdx, tMs, pqi)
% One application message: an 8-byte application header (packet id, type, origin) + filler.
MSG = struct('denm', 1, 'cam', 2, 'uni', 3);         % like the ITS PDU header messageID
id = numel(pkt) + 1;
hdr = [floor(id / 2^24), mod(floor(id / 2^16), 256), mod(floor(id / 2^8), 256), mod(id, 256), ...
       MSG.(type), u, 0, 0];
payload = [hdr, mod(id + (1:flow.sizeBytes - numel(hdr)), 256)];
[ue, ok] = stack.appSend(ue, flow.pqi, flow.pfi, dstL2, castLbl, payload, tMs);
row = cfg.pqiLookup(pqi, flow.pqi);
if ok
    pkt(end + 1) = struct('id', id, 'src', u, 'type', type, 'genMs', tMs, 'dst', dstIdx, 'pdbMs', row.PDB_ms);
end
end

function y = applyFading(ch, x, tSec)
% Evaluate the link's fading at the slot's wall-clock time (the link is only exercised in slots its
% transmitter is active, so the time is set explicitly rather than left to advance per call).
release(ch);
ch.InitialTime = tSec;
info = ch.info;
d = info.ChannelFilterDelay;
yy = ch([x; zeros(d, 1)]);
y = yy(d + 1:end);
end

function f = arfcnToHz(n)
% NR-ARFCN -> frequency, TS 38.104 clause 5.4.2.1 global raster: F = F_offs + dF (N - N_offs).
RASTER = [0 599999 5e3 0 0; 600000 2016666 15e3 3000e6 600000; 2016667 3279165 60e3 24250.08e6 2016667];
row = RASTER(n >= RASTER(:, 1) & n <= RASTER(:, 2), :);
f = row(4) + row(3) * (n - row(5));
end
