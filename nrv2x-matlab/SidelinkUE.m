classdef SidelinkUE < handle
%SidelinkUE Rel-16 NR sidelink Mode 2 UE: sensing + SPS + re-eval/pre-emption.
%
%   Integrates (Plan.md §3):
%     config/       — preconfiguration, logical slot map (T'_max)
%     phy/sensing/  — sensing database + TS 38.214 8.1.4 selector
%     mac/          — grant/SPS/counters/triggers/re-eval/pre-emption
%     rf/           — 23 dBm analog-equivalent transmitter
%
%   Two-phase slot protocol for the multi-UE harness (Plan.md §4.3):
%     txInfo = ue.txPhase(n)          all UEs first
%     ue.rxPhase(n, rxList)           then deliveries; rxList entries:
%        .startSub .LsubCH .prio .Prsvp_ms .rsrp_dBm .trivLog
%   Half-duplex: a UE that transmitted in slot n ignores rxList and the
%   slot is marked unmonitored in its sensing database (§0.4).
%
%   Waveform path: getWaveform() returns [bb, rfSig, rfInfo], maximising
%   5G Toolbox use: the Version 3 SidelinkPHYEntity (full nr* chain:
%   nrLDPC SL-SCH, nrPolar SCI, DM-RS, nrOFDMModulate) when on the path
%   (setupPaths adds it by default), else a toolbox nrOFDMModulate QPSK
%   slot. MAC/sensing behaviour is identical either way.

    properties
        L2ID        % 24-bit source layer-2 ID (default 0x100000 + ID)
    end

    properties (SetAccess = private)
        ID
        cfg
        slotMap
        db          % SensingDatabase
        mac         % MacEntity
        rf          % RFModule
        rs          % RandStream
        phy = []    % optional Version 3 SidelinkPHYEntity
        txLog = zeros(0, 3)    % [absSlot startSub LsubCH]
        lastTxSlot = -1
    end

    methods
        function obj = SidelinkUE(id, cfg, nSlotsSim, seed)
            if nargin < 2 || isempty(cfg), cfg = defaultPreconfig(); end
            if nargin < 3, nSlotsSim = 2000; end
            if nargin < 4, seed = 100 + id; end

            obj.ID   = id;
            obj.L2ID = 1048576 + id;           % 0x100000 + id
            obj.cfg  = cfg;
            obj.slotMap = deriveLogicalSlots(cfg, nSlotsSim);
            obj.db  = SensingDatabase(cfg, obj.slotMap);
            obj.rs  = RandStream('mt19937ar', 'Seed', seed);
            obj.mac = MacEntity(cfg, obj.slotMap, obj.db, obj.rs);
            obj.rf  = RFModule('SampleRate', 30.72e6);
            % Version 3 PHY (full 5G Toolbox chain) is constructed lazily
            % on the first getWaveform() call — see below.
        end

        function configureTraffic(obj, prio, Prsvp_ms, LsubCH, pdb_ms)
            %configureTraffic Set the MAC grant parameters for this UE.
            obj.mac.prioTx   = prio;
            obj.mac.Prsvp_ms = Prsvp_ms;
            obj.mac.LsubCH   = LsubCH;
            obj.mac.pdb_ms   = pdb_ms;
        end

        function txInfo = txPhase(obj, n)
            %txPhase MAC slot processing; returns tx decision or [].
            txInfo = obj.mac.runSlot(n);
            if ~isempty(txInfo)
                obj.db.markUnmonitored(n);         % half-duplex (8.1.4 step 2)
                obj.lastTxSlot = n;
                obj.txLog(end+1, :) = [n, txInfo.startSub, txInfo.LsubCH];
            end
        end

        function rxPhase(obj, n, rxList)
            %rxPhase Deliver other UEs' SCIs (abstract PHY, Plan.md §11).
            if obj.lastTxSlot == n
                return;                            % half-duplex: heard nothing
            end
            if n + 1 <= numel(obj.slotMap.abs2logical) && ...
                    ~isnan(obj.slotMap.abs2logical(n + 1))
                obj.db.markMonitored(n);
            end
            for k = 1:numel(rxList)
                r = rxList(k);
                triv = [];  src = 0;
                if isfield(r, 'trivLog'),  triv = r.trivLog;  end
                if isfield(r, 'srcL2Id'),  src  = r.srcL2Id;  end
                obj.db.addRecord(n, r.startSub, r.LsubCH, r.prio, ...
                    r.Prsvp_ms, r.rsrp_dBm, triv, src);
            end
        end

        function [bb, rfSig, rfInfo] = getWaveform(obj)
            %getWaveform One slot of baseband IQ through the RF module.
            %   Prefers the Version 3 SidelinkPHYEntity — the complete
            %   5G Toolbox sidelink chain (SL-SCH LDPC, SCI polar, DM-RS,
            %   AGC/guard symbols, nrOFDMModulate). Falls back to a
            %   toolbox nrOFDMModulate QPSK slot.
            if isempty(obj.phy) && exist('SidelinkPHYEntity', 'class') == 8
                try %#ok<TRYNC> % Version 3 PHY needs 5G Toolbox
                    obj.phy = SidelinkPHYEntity();
                end
            end
            if ~isempty(obj.phy)
                bb = obj.phy.transmitSlot();
                obj.rf.SampleRate = nrOFDMInfo(obj.phy.Pool.SCSCarrier).SampleRate;
            else
                [bb, prm] = ofdmBaseband(obj.rs);
                obj.rf.SampleRate = prm.SampleRate;
            end
            [rfSig, rfInfo] = obj.rf.transmit(bb);
        end

        function s = getStats(obj)
            s = obj.mac.stats;
            s.txSlots = obj.txLog(:, 1)';
            s.nTx = size(obj.txLog, 1);
        end
    end
end
