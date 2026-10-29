function r = run(c)
%run Continuous-time, waveform-level multi-UE deployment: real IQ, real hardware, summed signals.
%Spec:   none -- a harness. The UEs are +stack/ (every 3GPP layer from the stored preconfiguration);
%        this function is everything between their antennas: transmitter hardware, the per-link
%        channel, the propagation delay, the SUMMATION of every arriving waveform, and receiver
%        hardware. Interference is never computed by formula -- it is what the summed waveform does
%        to the receiver's own channel estimation and decoding.
%Inputs: c  deployConfig()
%Outputs: r  struct, compatible with harness.field.collisions and extended for per-UE statistics:
%   .pkt    every application packet: .id .src .type ('cam'|'evt') .genMs .dst (0 = broadcast) .pdbMs
%   .rx     every delivery: .id .rxUe .rxMs .bytes
%   .txLog  every PSSCH transmission: .ue .ms .startSubch .LsubCH .prio .cast .lcids .isRetx .harqId
%   .rxLog  every PSCCH decoded: .ue .ms .startSubch .LsubCH .sourceID .tbOk .rsrpDbm
%   .rssiDbm  N x nSlots x numSubchannel single -- S-RSSI per sub-channel per slot (NaN where the UE
%           transmitted: half duplex), the input to CBR
%   .agc    N x nSlots single -- AGC gain (dB) applied in each slot; .clip N x nSlots, clipped share
%   .ues    final UE structs; .drop (positions, velocities, timing/frequency errors); .c the config
%   .linkSnrDb  N x N per-RE SNR of a 10-PRB PSSCH at t = 0 (path loss only), for collisions()
%
%THE TIME BASE, AND WHY ENERGY CROSSES SLOT BOUNDARIES
%-----------------------------------------------------
%Every UE keeps slot time to a GNSS-disciplined reference with its own error d_u. Transmitter i's
%slot n leaves at n*T + d_i and reaches j after the propagation delay r_ij/c. Receiver j opens its
%slot-n FFT window at n*T + d_j - G, G samples early (inside the cyclic prefix), so the signal sits
%  o_ij = (d_i - d_j + r_ij / c) * fs + G   samples (fractional) into j's window,
%and its last o_ij samples land in j's NEXT window. Each receiver therefore keeps a two-slot
%buffer: what spills out of slot n is already waiting when slot n+1 is processed. Arrivals later
%than CP - G samples (~700 m at 30 kHz SCS with the default G) put inter-symbol interference into
%the decoder exactly as a real receiver would see it.
%
%THE LINK GRAPH
%--------------
%Positions advance every slot (constant velocity, reflected at the field edge). A directed link
%i -> j is simulated while its mean received power is within c.radio.pruneMarginDb below j's
%thermal noise over the occupied band; weaker links cannot change a decision and are dropped.
%Each simulated link has its own TDL fading channel, created when first needed, whose time is set
%to the slot's absolute time on every use, with Doppler from |v_i| + |v_j| (scatterers static).
%
%PARALLELISM WITHOUT CHANGING THE ANSWER
%---------------------------------------
%Each worker permanently owns a subset of UEs (stack state, hardware, the fading channels INTO
%them). Per slot the workers exchange only the transmitted waveforms (spmdCat). Every random
%stream belongs to a UE or a link and is seeded from the UE/link identity, so the result does not
%depend on the number of workers.
o = cfg.loadConfig(c.cfgPath, [c.cam.pqi c.evt.pqi]);
% sl-ProbResourceKeep override (sl-UE-SelectedPreConfig-r16, TS 38.321 5.22.1.1): a different
% preconfigured value, applied to the loaded tree exactly as the JSON would carry it. [] keeps the
% stored one (v0dot8, the SAE J3161 value).
if isfield(c.impl, 'probResourceKeep') && ~isempty(c.impl.probResourceKeep)
    PROB_KEEP_VALUES = [0 0.2 0.4 0.6 0.8];              % ENUMERATED {v0, v0dot2, ..., v0dot8}
    if ~any(abs(c.impl.probResourceKeep - PROB_KEEP_VALUES) < 1e-12)
        error('deploy:run:probResourceKeep', 'sl-ProbResourceKeep must be one of %s, got %g', ...
            mat2str(PROB_KEEP_VALUES), c.impl.probResourceKeep);
    end
    o.preconfig.sl_UE_SelectedPreConfig_r16.sl_ProbResourceKeep_r16 = c.impl.probResourceKeep;
    o.preconfig.sl_UE_SelectedPreConfig_r16.sl_ProbResourceKeep_r16_Present = true;
end
k = stack.defaults();
k.noiseFigureDb = c.hw.rx.noiseFigureDb;
k.tReorderingMs = c.impl.tReorderingMs;
k.t2MaxMs = c.impl.t2MaxMs;
if isfield(c.impl, 'mcs'), k.mcs = c.impl.mcs; end
if isfield(c.impl, 'decodeMarginSlots'), k.decodeMarginSlots = c.impl.decodeMarginSlots; end
if isfield(c.impl, 'prsvpTxMs'), k.prsvpTxMs = c.impl.prsvpTxMs; end   % 0 dynamic, > 0 SPS
if isfield(c.impl, 'gcbcRxOutOfOrder'), k.gcbcRxOutOfOrder = c.impl.gcbcRxOutOfOrder; end
drop = harness.deploy.drop(c);
N = drop.N;
l2 = hex2dec('100000') + (1:N);
probe = stack.ueInit(o, l2(1), c.broadcastL2Id, k, c.sim.seed);
g = probe.g;
[~, fs] = phy.lib.ofdmMod(complex(zeros(g.nSubcarriers, g.NsymbSlot)), g.mu, 0);
Ns = numel(phy.lib.ofdmMod(complex(zeros(g.nSubcarriers, g.NsymbSlot)), g.mu, 0));
Ts = g.slotMs / 1000;
assert(g.slotMs == 0.5, 'deploy.run: harness.deploy.drop draws CAM phases at 2 slots per ms (mu = 1); got a %g ms slot', g.slotMs);
% Run length from a PACKET COUNT when no duration is given: c.sim.nPackets CAMs in total over the
% N dropped UEs, one period for the per-UE phases, and the longest PDB in use to drain.
% Which UEs generate CAMs (c.cam.txUe; [] = every UE).
camTx = 1:N; if isfield(c.cam, 'txUe') && ~isempty(c.cam.txUe), camTx = c.cam.txUe; end
camQuota = inf;                        % CAMs per transmitting UE; finite only when sized by count
if isempty(c.sim.durationMs)
    camQuota = ceil(c.sim.nPackets / numel(camTx));
    pq0 = cfg.pqiTable();
    maxPdbMs = max(cfg.pqiLookup(pq0, c.cam.pqi).PDB_ms, cfg.pqiLookup(pq0, c.evt.pqi).PDB_ms);
    c.sim.durationMs = (camQuota + 1) * c.cam.periodMs + maxPdbMs;
    fprintf('deploy: %d CAMs over %d transmitting UEs -> %.2f s of air time\n', c.sim.nPackets, numel(camTx), c.sim.durationMs / 1000);
end
nSlots = round(c.sim.durationMs / g.slotMs);
C_LIGHT = 299792458;
G = c.hw.sync.fftAdvanceSamples;
AGC_SAMPLES = round(Ns / g.NsymbSlot);
gAnt = 0; if isfield(c.radio, 'antennaGainDb'), gAnt = c.radio.antennaGainDb; end   % TX + RX combined
plModel = harness.chanmodel.pathlossModel(c.radio.plModel, struct('fcHz', c.radio.fcHz, ...
    'losMode', c.radio.losMode, 'hTxM', c.radio.hAntM, 'hRxM', c.radio.hAntM, 'antennaGainDb', gAnt));
occBwHz = g.nRbBwp * 12 * 15e3 * 2^g.mu;
noiseOccDbm = rf.noiseFloorDbm(occBwHz, c.hw.rx.noiseFigureDb);
pruneDbm = noiseOccDbm - c.radio.pruneMarginDb;
pqi = cfg.pqiTable();
pdb = struct('cam', cfg.pqiLookup(pqi, c.cam.pqi).PDB_ms, 'evt', cfg.pqiLookup(pqi, c.evt.pqi).PDB_ms);
camOff = drop.camOffsetSlots;
% RE power out of phy.lib.ofdmDemod -> watts: calibrated ONCE on a full-band slot of known power
% (1 W over its transmitted samples), so the S-RSSI below is in absolute dBm.
calRs = RandStream('mt19937ar', 'Seed', 1);
gCal = (sign(randn(calRs, g.nSubcarriers, g.NsymbSlot)) + 1j * sign(randn(calRs, g.nSubcarriers, g.NsymbSlot))) / sqrt(2);
xCal = phy.lib.ofdmMod(gCal, g.mu, 0);
xCal = xCal / sqrt(mean(abs(xCal).^2));
GCal = phy.lib.ofdmDemod(xCal, g.nSubcarriers, g.mu, 0);
reToW = 1 / mean(sum(abs(GCal).^2, 1));
nW = min(c.sim.nWorkers, N);
owner = mod((0:N - 1), nW) + 1;
if isempty(gcp('nocreate')), parpool('Processes', nW); end
cc = c;

spmd(nW)
    w = spmdIndex;
    mine = find(owner == w);
    ues = cell(1, N); txhw = cell(1, N); rxhw = cell(1, N); trs = cell(1, N);
    buf = cell(1, N); fade = cell(N, N); cnt = zeros(1, N); camSent = zeros(1, N);
    for u = mine
        ues{u} = stack.ueInit(o, l2(u), cc.broadcastL2Id, k, cc.sim.seed + u);
        txhw{u} = rf.txHardwareInit(cc.hw, fs, cc.radio.fcHz, cc.sim.seed * 1000 + u);
        rxhw{u} = rf.rxHardwareInit(cc.hw, fs, cc.radio.fcHz, cc.sim.seed * 1000 + 500 + u);
        rxhw{u}.foHz = txhw{u}.foHz;                 % one oscillator per UE
        release(rxhw{u}.pfo); rxhw{u}.pfo.FrequencyOffset = -txhw{u}.foHz;
        trs{u} = RandStream('mt19937ar', 'Seed', cc.sim.seed * 7919 + u);
        buf{u} = complex(zeros(Ns, 1));
    end
    pkt = repmat(struct('id', 0, 'src', 0, 'type', '', 'genMs', 0, 'dst', 0, 'pdbMs', 0), 1, 0);
    rxL = repmat(struct('id', 0, 'rxUe', 0, 'rxMs', 0, 'bytes', 0), 1, 0);
    txL = repmat(struct('ue', 0, 'ms', 0, 'startSubch', 0, 'LsubCH', 0, 'prio', 0, 'cast', 0, ...
        'lcids', zeros(1, 0), 'isRetx', false, 'harqId', 0), 1, 0);
    decL = repmat(struct('ue', 0, 'ms', 0, 'startSubch', 0, 'LsubCH', 0, 'sourceID', -1, ...
        'tbOk', false, 'rsrpDbm', 0), 1, 0);
    rssi = nan(numel(mine), nSlots, g.numSubchannel, 'single');
    agc = nan(numel(mine), nSlots, 'single'); clip = zeros(numel(mine), nSlots, 'single');
    ex = struct('y', [], 'slot', -1, 'ue', 0, 'arrivals', zeros(0, 4), 'occ', false(1, g.numSubchannel));
    noiseSubDbm = rf.noiseFloorDbm(g.subchSizeRb * 12 * 15e3 * 2^g.mu, cc.hw.rx.noiseFigureDb);
    for n = 0:nSlots - 1
        t = n * Ts; tMs = n * g.slotMs;
        pos = harness.deploy.positions(drop, t, cc.field.sizeM);
        % ---- applications -----------------------------------------------------------
        for u = mine
            if ismember(u, camTx) && mod(n - camOff(u), round(cc.cam.periodMs / g.slotMs)) == 0 && n >= camOff(u) && camSent(u) < camQuota
                camSent(u) = camSent(u) + 1;
                cnt(u) = cnt(u) + 1;
                [ues{u}, pkt] = send(ues{u}, pkt, u, cnt(u), 'cam', cc.cam, cc.broadcastL2Id, tMs, pdb.cam);
            end
            if rand(trs{u}) < 1 - exp(-g.slotMs / cc.evt.meanMs)
                cnt(u) = cnt(u) + 1;
                [ues{u}, pkt] = send(ues{u}, pkt, u, cnt(u), 'evt', cc.evt, cc.broadcastL2Id, tMs, pdb.evt);
            end
        end
        % ---- transmit, through each UE's own hardware -------------------------------------
        myTx = cell(1, 0);
        for u = mine
            [ues{u}, iq, tx] = stack.txSlot(ues{u}, n);
            if isempty(iq), continue; end
            occ = false(1, g.numSubchannel);
            if ~isempty(tx), occ(tx.startSubch + (1:tx.LsubCH)) = true; end
            myTx{end + 1} = struct('u', u, 'iq', rf.txHardware(txhw{u}, iq, t + drop.timingErrS(u)), 'occ', occ); %#ok<AGROW>
            if ~isempty(tx)
                txL(end + 1) = struct('ue', u, 'ms', tMs, 'startSubch', tx.startSubch, 'LsubCH', tx.LsubCH, ...
                    'prio', tx.prio, 'cast', tx.cast, 'lcids', tx.lcids, 'isRetx', tx.isRetx, 'harqId', tx.harqId); %#ok<AGROW>
            end
        end
        allTx = spmdCat(myTx, 2);
        % ---- every owned receiver: sum the arrivals, receiver hardware, decode --------------
        for m = 1:numel(mine)
            j = mine(m);
            cur = buf{j}; nxt = complex(zeros(Ns, 1)); any_ = any(cur ~= 0);
            arr = zeros(0, 4);                       % [tx UE, offset samples, rx dBm, distance m]
            occAll = false(1, g.numSubchannel);
            for q = 1:numel(allTx)
                i = allTx{q}.u;
                if i == j, continue; end
                dij = norm(pos(i, :) - pos(j, :));
                pl = harness.chanmodel.pathloss(plModel, dij);
                if cc.hw.tx.pOutDbm - pl < pruneDbm, continue; end
                x = allTx{q}.iq * 10^(-pl / 20);
                if ~isempty(cc.radio.fading)
                    if isempty(fade{i, j})
                        dopKmh = (drop.speedMps(i) + drop.speedMps(j)) * 3.6;
                        if isfield(cc.radio, 'dopplerKmh') && ~isempty(cc.radio.dopplerKmh)
                            dopKmh = cc.radio.dopplerKmh;      % a set Doppler speed for every link
                        end
                        fade{i, j} = harness.chanmodel.tdlChannel(cc.radio.fading, cc.radio.delaySpreadNs, ...
                            dopKmh, cc.radio.fcHz, fs, cc.sim.seed * 100000 + i * 1000 + j);
                    end
                    x = applyFading(fade{i, j}, x, t);
                end
                off = (drop.timingErrS(i) - drop.timingErrS(j) + dij / C_LIGHT) * fs + G;
                [cur, nxt] = addDelayed(cur, nxt, x, off);
                any_ = true;
                arr(end + 1, :) = [i, off, cc.hw.tx.pOutDbm - pl, dij]; %#ok<AGROW>
                occAll = occAll | allTx{q}.occ;
            end
            buf{j} = nxt;
            if any_
                [y, info] = rf.rxHardware(rxhw{j}, cur, t + drop.timingErrS(j) - G / fs, AGC_SAMPLES);
                agc(m, n + 1) = info.agcGainDb; clip(m, n + 1) = info.clipFrac;
                % Keep one window with >= 2 arrivals, preferring one that leaves a sub-channel
                % EMPTY: only there is the transmitters' in-band emission visible on its own.
                if w == 1 && size(arr, 1) >= 2 && (isempty(ex.y) || (all(ex.occ) && ~all(occAll)))
                    ex = struct('y', y, 'slot', n, 'ue', j, 'arrivals', arr, 'occ', occAll);
                end
            else
                y = [];                      % nothing arrived: decoding pure noise cannot succeed
            end
            [ues{j}, out, dec] = stack.rxSlot(ues{j}, y, n);
            % S-RSSI per sub-channel (TS 38.215 5.1.27: average total received power over the
            % sub-channel in the sidelink symbols), NaN in a slot this UE transmitted in.
            if ues{j}.lastTx.slot == n && ues{j}.lastTx.pssch
                rssi(m, n + 1, :) = NaN;
            elseif isempty(y)
                rssi(m, n + 1, :) = noiseSubDbm;
            else
                G2 = phy.lib.ofdmDemod(y, g.nSubcarriers, g.mu, mod(n, 10 * 2^g.mu));
                pw = abs(G2(:, g.firstSymbol + (0:g.ld - 1) + 1)).^2;
                for s = 1:g.numSubchannel
                    sc = 12 * g.subchStartRb(s) + (1:12 * g.subchSizeRb);
                    rssi(m, n + 1, s) = 10 * log10(mean(sum(pw(sc, :), 1)) * reToW) + 30;
                end
            end
            for q = 1:numel(dec)
                decL(end + 1) = struct('ue', j, 'ms', tMs, 'startSubch', dec(q).startSubch, ...
                    'LsubCH', dec(q).LsubCH, 'sourceID', dec(q).sourceID, 'tbOk', dec(q).tbOk, ...
                    'rsrpDbm', dec(q).rsrpDbm); %#ok<AGROW>
            end
            for q = 1:numel(out)
                p = out(q).payload;
                id = p(1) * 2^24 + p(2) * 2^16 + p(3) * 2^8 + p(4);
                rxL(end + 1) = struct('id', id, 'rxUe', j, 'rxMs', tMs, 'bytes', numel(p)); %#ok<AGROW>
            end
        end
    end
    finalUes = ues(mine);
    exOut = ex;
end

% ---- gather -----------------------------------------------------------------------------
P = {}; X = {}; T = {}; Dd = {};
for w = 1:nW
    P{end + 1} = pkt{w}; X{end + 1} = rxL{w}; T{end + 1} = txL{w}; Dd{end + 1} = decL{w}; %#ok<AGROW>
end
r.pkt = [P{:}]; r.rx = [X{:}]; r.txLog = [T{:}]; r.rxLog = [Dd{:}];
r.rssiDbm = nan(N, nSlots, g.numSubchannel, 'single');
r.agc = nan(N, nSlots, 'single'); r.clip = zeros(N, nSlots, 'single');
ueCell = cell(1, N);
for w = 1:nW
    mineW = find(owner == w);
    rw = rssi{w}; aw = agc{w}; cw = clip{w}; uw = finalUes{w};
    r.rssiDbm(mineW, :, :) = rw; r.agc(mineW, :) = aw; r.clip(mineW, :) = cw;
    ueCell(mineW) = uw;
end
r.ues = [ueCell{:}];
r.example = exOut{1};
r.drop = drop; r.c = c; r.g = g; r.nSlots = nSlots; r.fs = fs;
% compatibility with harness.field.collisions: initial positions and a path-loss-only SNR matrix
r.c.ue.x = drop.xy0(:, 1)'; r.c.ue.y = drop.xy0(:, 2)'; r.c.ue.l2Id = l2;
r.c.sim.durationMs = c.sim.durationMs;
noiseRe = rf.noiseFloorDbm(15e3 * 2^g.mu, c.hw.rx.noiseFigureDb);
D = sqrt((drop.xy0(:, 1) - drop.xy0(:, 1)').^2 + (drop.xy0(:, 2) - drop.xy0(:, 2)').^2);
r.linkSnrDb = c.hw.tx.pOutDbm - 10 * log10(120) - reshape(harness.chanmodel.pathloss(plModel, max(D(:), 1)), N, N) - noiseRe;
r.linkSnrDb(1:N + 1:end) = NaN;
end

% =========================================================================================
function [ue, pkt] = send(ue, pkt, u, k, type, flow, dstL2, tMs, pdbMs)
%send One application message: an 8-byte ITS-style header (packet id, type, origin) + filler. The
%id is u * 2^20 + k, unique across workers without any coordination.
MSG = struct('evt', 1, 'cam', 2);
id = u * 2^20 + k;
hdr = [floor(id / 2^24), mod(floor(id / 2^16), 256), mod(floor(id / 2^8), 256), mod(id, 256), ...
    MSG.(type), mod(u, 256), 0, 0];
payload = [hdr, mod(id + (1:flow.sizeBytes - numel(hdr)), 256)];
[ue, ok] = stack.appSend(ue, flow.pqi, flow.pfi, dstL2, 'broadcast', payload, tMs);
if ok
    pkt(end + 1) = struct('id', id, 'src', u, 'type', type, 'genMs', tMs, 'dst', 0, 'pdbMs', pdbMs);
end
end

function [cur, nxt] = addDelayed(cur, nxt, x, off)
%addDelayed Add x into the two-slot window [cur; nxt] starting off samples in (fractional), by an
%FFT phase ramp for the fractional part. Padding keeps the circular shift from wrapping the tail.
PAD = 64;
Ns = numel(cur);
mInt = floor(off); f = off - mInt;
L = numel(x) + PAD;
X = fft([x; complex(zeros(PAD, 1))]);
kk = [0:ceil(L / 2) - 1, -floor(L / 2):-1]';
xf = ifft(X .* exp(-1j * 2 * pi * kk * f / L));
both = [cur; nxt];
hi = min(2 * Ns, mInt + L);
both(mInt + 1:hi) = both(mInt + 1:hi) + xf(1:hi - mInt);
cur = both(1:Ns); nxt = both(Ns + 1:end);
end

function y = applyFading(ch, x, tSec)
% The link's fading at the slot's absolute time; filter delay removed (as harness.field.run).
release(ch);
ch.InitialTime = tSec;
d = ch.info.ChannelFilterDelay;
yy = ch([x; zeros(d, 1)]);
y = yy(d + 1:end);
end

