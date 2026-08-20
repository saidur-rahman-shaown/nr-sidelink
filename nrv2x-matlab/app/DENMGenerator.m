classdef DENMGenerator < handle
%DENMGenerator ETSI ITS Decentralized Environmental Notification generator
%
%   Generates and parses DENM messages per ETSI EN 302 637-3 v1.3.1.
%   DENM is the hazard/event notification message type used to alert
%   nearby vehicles of detected road hazards or traffic events.
%
%   DENM PDU binary layout (compact simulation encoding):
%     Bytes 0-1:   MessageID = 0x0001 (DENM)
%     Bytes 2-5:   OriginatingStationID (uint32)
%     Bytes 6-7:   SequenceNumber (uint16)
%     Bytes 8-13:  DetectionTime (uint48 / 6 bytes, ms since 2004-01-01 mod 2^48)
%     Bytes 14-19: ReferenceTime (uint48)
%     Byte  20:    Termination (uint8: 0=isCancellation, 1=isNegation, 2=notUsed)
%     Bytes 21-24: EventLatitude  (int32, 1e-7 deg)
%     Bytes 25-28: EventLongitude (int32, 1e-7 deg)
%     Bytes 29-30: EventAltitude  (int16, 0.01 m)
%     Byte  31:    InformationQuality (uint8, 0=unavail, 1..7=quality)
%     Byte  32:    CauseCode (uint8, see below)
%     Byte  33:    SubCauseCode (uint8)
%     Bytes 34-35: EventSpeed     (uint16, 0.01 m/s)
%     Bytes 36-37: EventHeading   (uint16, 0.1 deg)
%     Byte  38:    RelevanceDistance (uint8, see enum)
%     Byte  39:    StationType    (uint8)
%   Total: 40 bytes
%
%   DENM Cause Codes (EN 302 637-3 Annex B):
%     0  = reserved
%     1  = trafficCondition
%     2  = accident
%     3  = roadworks
%     6  = adverseWeatherCondition_Visibility
%     9  = adverseWeatherCondition_Adhesion
%     10 = hazardousLocation_SurfaceCondition
%     11 = hazardousLocation_ObstacleOnTheRoad
%     12 = hazardousLocation_AnimalOnTheRoad
%     14 = humanPresenceOnTheRoad
%     17 = wrongWayDriving
%     18 = rescueAndRecoveryWorkInProgress
%     19 = adverseWeatherCondition_ExtremeWeatherCondition
%     26 = slowVehicle
%     27 = dangerousEndOfQueue
%     91 = vehicleBreakdown
%     92 = postCrash
%     93 = humanProblem
%     94 = stationaryVehicle
%     95 = emergencyVehicleApproaching
%     96 = hazardousLocation_DangerousCurve
%     97 = collisionRisk
%     98 = signalViolation
%     99 = dangerousSituation
%
%   BTP destination port: 2002
%
%   References:
%     ETSI EN 302 637-3 v1.3.1 — DENM specification
%     ETSI TS 102 894-2 — ITS data dictionary

%   Copyright 2025. NR Sidelink Simulation Platform.

    properties (Constant)
        MESSAGE_ID      = uint16(1)   % DENM message ID
        PDU_SIZE_BYTES  = 40          % Compact binary PDU size
        BTP_PORT        = 2002        % BTP port for DENM

        % Cause codes (subset)
        CAUSE_TRAFFIC_COND     = 1
        CAUSE_ACCIDENT         = 2
        CAUSE_ROADWORKS        = 3
        CAUSE_WEATHER_VIS      = 6
        CAUSE_WEATHER_ADHESION = 9
        CAUSE_SURFACE_COND     = 10
        CAUSE_OBSTACLE         = 11
        CAUSE_ANIMAL           = 12
        CAUSE_HUMAN_PRESENCE   = 14
        CAUSE_WRONG_WAY        = 17
        CAUSE_SLOW_VEHICLE     = 26
        CAUSE_END_OF_QUEUE     = 27
        CAUSE_BREAKDOWN        = 91
        CAUSE_POST_CRASH       = 92
        CAUSE_STATIONARY_VEH   = 94
        CAUSE_EMERGENCY_VEH    = 95
        CAUSE_COLLISION_RISK   = 97

        % Relevance distance
        RELEV_DIST_50M   = 1
        RELEV_DIST_100M  = 2
        RELEV_DIST_200M  = 3
        RELEV_DIST_500M  = 4
        RELEV_DIST_1000M = 5
        RELEV_DIST_5KM   = 6
        RELEV_DIST_10KM  = 7
        RELEV_DIST_INF   = 8
    end

    properties
        StationID   (1,1) uint32 = 0
        StationType (1,1) uint8  = 5
    end

    properties (SetAccess = private)
        NextSeqNum  (1,1) uint16 = 0   % Per-station DENM sequence number
        ActiveDENMs = struct()          % actionID → DENM struct (active events)

        TxCount     (1,1) uint32 = 0
        RxCount     (1,1) uint32 = 0
        CancelCount (1,1) uint32 = 0
    end

    methods
        function obj = DENMGenerator(stationID, stationType)
        %DENMGenerator Construct for a given ITS station
            if nargin < 1; stationID   = 0; end
            if nargin < 2; stationType = 5; end
            obj.StationID   = uint32(stationID);
            obj.StationType = uint8(stationType);
        end

        %% ----- TX -----

        function [pdu, actionID] = triggerDENM(obj, causeCode, eventPos, opts)
        %triggerDENM Generate a DENM for a new event
        %   causeCode: uint8 cause code (e.g., CAUSE_ACCIDENT)
        %   eventPos:  struct with Lat_deg, Long_deg, Alt_m
        %   opts:      struct with optional fields:
        %                SubCauseCode (uint8, default 0)
        %                InformationQuality (uint8, 0-7, default 5)
        %                Speed_ms   (double, event speed, default 0)
        %                Heading_deg (double, default 0)
        %                RelevanceDistance (uint8, default RELEV_DIST_1000M)
        %                Termination (uint8, default 2)
        %
        %   Returns pdu (uint8 bytes) and actionID struct.
            if nargin < 4; opts = struct(); end
            if nargin < 3 || isempty(eventPos)
                eventPos = struct('Lat_deg', 0, 'Long_deg', 0, 'Alt_m', 0);
            end

            subCause = getOpt(opts, 'SubCauseCode', 0);
            iq       = getOpt(opts, 'InformationQuality', 5);
            evSpd    = getOpt(opts, 'Speed_ms', 0);
            evHdg    = getOpt(opts, 'Heading_deg', 0);
            relDist  = getOpt(opts, 'RelevanceDistance', obj.RELEV_DIST_1000M);
            termCode = getOpt(opts, 'Termination', 2);   % 2 = notUsed (active DENM)

            seqNum   = obj.NextSeqNum;
            obj.NextSeqNum = uint16(mod(double(obj.NextSeqNum) + 1, 65536));

            actionID = struct('OriginatingStationID', obj.StationID, 'SequenceNumber', seqNum);
            detTime  = obj.currentTimestamp();
            refTime  = detTime;

            % Encode
            pdu = obj.encodeDENM(seqNum, detTime, refTime, termCode, ...
                                  eventPos, iq, causeCode, subCause, ...
                                  evSpd, evHdg, relDist);

            % Store as active event
            key = sprintf('s%u_q%u', obj.StationID, seqNum);
            obj.ActiveDENMs.(key) = struct( ...
                'actionID', actionID, 'causeCode', causeCode, ...
                'pos', eventPos, 'active', true);

            obj.TxCount = obj.TxCount + 1;
        end

        function pdu = cancelDENM(obj, actionID)
        %cancelDENM Generate a DENM cancellation for an active event
        %   actionID: struct from triggerDENM, or {stationID, seqNum} cell
            seqNum = actionID.SequenceNumber;
            eventPos = struct('Lat_deg', 0, 'Long_deg', 0, 'Alt_m', 0);

            key = sprintf('s%u_q%u', actionID.OriginatingStationID, seqNum);
            if isfield(obj.ActiveDENMs, key)
                eventPos = obj.ActiveDENMs.(key).pos;
                obj.ActiveDENMs.(key).active = false;
            end

            detTime = obj.currentTimestamp();
            pdu = obj.encodeDENM(seqNum, detTime, detTime, 0, ...  % termination=0 (cancellation)
                                  eventPos, 0, 0, 0, 0, 0, obj.RELEV_DIST_50M);
            obj.CancelCount = obj.CancelCount + 1;
        end

        %% ----- RX -----

        function denm = parseDENM(obj, pdu)
        %parseDENM Decode a received DENM PDU
        %   Returns struct or [] if malformed.
            denm = [];
            if isempty(pdu) || numel(pdu) < obj.PDU_SIZE_BYTES; return; end
            pdu = uint8(pdu(:)');

            msgID = uint16(double(pdu(1))*256 + double(pdu(2)));
            if msgID ~= obj.MESSAGE_ID; return; end

            denm.MessageID          = msgID;
            denm.OriginatingStationID = obj.bytesToU32(pdu(3:6));
            denm.SequenceNumber       = uint16(double(pdu(7))*256 + double(pdu(8)));
            denm.DetectionTime        = obj.bytesToU48(pdu(9:14));
            denm.ReferenceTime        = obj.bytesToU48(pdu(15:20));
            denm.Termination          = pdu(21);
            denm.EventLatitude_deg    = double(obj.bytesToI32(pdu(22:25))) * 1e-7;
            denm.EventLongitude_deg   = double(obj.bytesToI32(pdu(26:29))) * 1e-7;
            denm.EventAltitude_m      = double(obj.bytesToI16(pdu(30:31))) * 0.01;
            denm.InformationQuality   = pdu(32);
            denm.CauseCode            = pdu(33);
            denm.SubCauseCode         = pdu(34);
            denm.EventSpeed_ms        = (double(pdu(35))*256 + double(pdu(36))) * 0.01;
            denm.EventHeading_deg     = (double(pdu(37))*256 + double(pdu(38))) * 0.1;
            denm.RelevanceDistance    = pdu(39);
            denm.StationType          = pdu(40);
            denm.IsCancellation       = (denm.Termination == 0);

            obj.RxCount = obj.RxCount + 1;
        end

        function active = getActiveDENMs(obj)
        %getActiveDENMs Return list of active (non-cancelled) DENM action IDs
            active = {};
            fn = fieldnames(obj.ActiveDENMs);
            for i = 1:numel(fn)
                if obj.ActiveDENMs.(fn{i}).active
                    active{end+1} = obj.ActiveDENMs.(fn{i}).actionID; %#ok<AGROW>
                end
            end
        end

        function stats = getStats(obj)
        %getStats Return statistics struct
            stats = struct( ...
                'TxDENMs',      obj.TxCount, ...
                'RxDENMs',      obj.RxCount, ...
                'Cancellations', obj.CancelCount, ...
                'ActiveEvents',  numel(obj.getActiveDENMs()));
        end

        function reset(obj)
            obj.NextSeqNum  = 0;
            obj.ActiveDENMs = struct();
            obj.TxCount     = 0;
            obj.RxCount     = 0;
            obj.CancelCount = 0;
        end
    end

    %% ----- Private helpers -----
    methods (Access = private)

        function pdu = encodeDENM(obj, seqNum, detTime, refTime, termCode, ...
                                   eventPos, iq, causeCode, subCause, ...
                                   evSpd, evHdg, relDist)
            lat_raw = int32(max(-900000000, min(900000000, round(eventPos.Lat_deg * 1e7))));
            lon_raw = int32(max(-1800000000, min(1800000000, round(eventPos.Long_deg * 1e7))));
            alt_raw = int16(max(-10000, min(800001, round(eventPos.Alt_m * 100))));
            spd_raw = uint16(min(16382, round(max(0, evSpd) * 100)));
            hdg_raw = uint16(min(3600, round(mod(evHdg,360) * 10)));

            pdu = [ ...
                uint8(0), uint8(obj.MESSAGE_ID), ...         % MessageID
                obj.u32ToBytes(obj.StationID), ...            % StationID
                uint8(bitshift(seqNum,-8)), uint8(seqNum&255),...% SeqNum
                obj.u48ToBytes(detTime), ...                  % DetectionTime
                obj.u48ToBytes(refTime), ...                  % ReferenceTime
                uint8(termCode), ...                          % Termination
                obj.i32ToBytes(lat_raw), ...                  % EventLat
                obj.i32ToBytes(lon_raw), ...                  % EventLon
                obj.i16ToBytes(alt_raw), ...                  % EventAlt
                uint8(iq), ...                                % InfoQuality
                uint8(causeCode), ...                         % CauseCode
                uint8(subCause), ...                          % SubCauseCode
                uint8(bitshift(spd_raw,-8)), uint8(spd_raw & 255), ...% EventSpeed
                uint8(bitshift(hdg_raw,-8)), uint8(hdg_raw & 255), ...% EventHeading
                uint8(relDist), ...                           % RelevanceDistance
                obj.StationType ...                           % StationType
            ];
        end

        function t = currentTimestamp(~)
            % Milliseconds since 2004-01-01 (ITS epoch), mod 2^48
            % In simulation, use wall clock difference
            persistent t0;
            if isempty(t0); t0 = 0; end
            t = uint64(mod(round(posixtime(datetime('now')) - ...
                posixtime(datetime(2004,1,1,0,0,0))) * 1000, 2^48));
        end

        function b = u48ToBytes(~, v)
            v = uint64(v);
            b = uint8([ ...
                double(bitshift(v,-40) & 255), double(bitshift(v,-32) & 255), ...
                double(bitshift(v,-24) & 255), double(bitshift(v,-16) & 255), ...
                double(bitshift(v,-8)  & 255), double(v & 255)]);
        end

        function v = bytesToU48(~, b)
            v = uint64(double(b(1))*(2^40) + double(b(2))*(2^32) + ...
                       double(b(3))*(2^24) + double(b(4))*(2^16) + ...
                       double(b(5))*256 + double(b(6)));
        end

        function b = u32ToBytes(~, v)
            b = uint8([bitshift(uint32(v),-24)&255, bitshift(uint32(v),-16)&255, ...
                       bitshift(uint32(v),-8)&255, uint32(v)&255]);
        end

        function b = i32ToBytes(~, v)
            v = int32(v);
            b = uint8([bitshift(v,-24)&255, bitshift(v,-16)&255, ...
                       bitshift(v,-8)&255, v&255]);
        end

        function b = i16ToBytes(~, v)
            v = int16(v);
            b = uint8([bitshift(v,-8)&255, v&255]);
        end

        function v = bytesToU32(~, b)
            v = uint32(double(b(1))*16777216 + double(b(2))*65536 + ...
                       double(b(3))*256 + double(b(4)));
        end

        function v = bytesToI32(~, b)
            u = uint32(double(b(1))*16777216 + double(b(2))*65536 + ...
                       double(b(3))*256 + double(b(4)));
            if u >= 2^31; v = int32(u) - int32(2^32); else; v = int32(u); end
        end

        function v = bytesToI16(~, b)
            u = uint16(double(b(1))*256 + double(b(2)));
            if u >= 2^15; v = int16(u) - int16(2^16); else; v = int16(u); end
        end
    end
end

function v = getOpt(s, field, default)
%getOpt Helper: get struct field or return default
    if isfield(s, field); v = s.(field); else; v = default; end
end
