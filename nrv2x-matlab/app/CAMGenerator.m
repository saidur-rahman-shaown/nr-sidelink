classdef CAMGenerator < handle
%CAMGenerator ETSI ITS Cooperative Awareness Message generator (EN 302 637-2)
%
%   Generates and parses Cooperative Awareness Messages (CAM) per
%   ETSI EN 302 637-2 v1.4.1. CAM is the fundamental V2V safety message,
%   transmitted by all ITS stations to announce their presence and state.
%
%   CAM PDU binary layout (custom compact encoding for simulation):
%     Bytes 0-1:   MessageID = 0x0002 (CAM)
%     Bytes 2-5:   StationID (uint32)
%     Bytes 6-7:   GenerationDeltaTime (uint16, ms mod 65536)
%     Byte  8:     StationType (uint8, 5=car, 10=truck, 15=RSU)
%     Bytes 9-12:  Latitude  (int32, 0.1 microdegree, 1e-7 deg resolution)
%     Bytes 13-16: Longitude (int32, 0.1 microdegree)
%     Bytes 17-18: Altitude  (int16, 0.01m, -10000=unavailable)
%     Bytes 19-20: Speed     (uint16, 0.01 m/s, 0-16383, 16383=unavailable)
%     Bytes 21-22: Heading   (uint16, 0.1 degree, 0-3601, 3601=unavailable)
%     Bytes 23-24: LongitudinalAcceleration (int16, 0.1 m/s², ±160, 161=unavail)
%     Byte  25:    CurvatureCalculationMode (uint8, 0=YAWRATEUSED, 1=NOTUSED)
%     Bytes 26-27: YawRate   (int16, 0.01 deg/s, ±32766, 32767=unavailable)
%     Byte  28:    VehicleRole (uint8, 0=DEFAULT, 1=PUBLICTR, 2=SPECIALTR, ...)
%     Byte  29:    ExteriorLights (uint8, bitmask: bit0=LowBeam, bit1=HighBeam, ...)
%   Total: 30 bytes minimum (compact encoding)
%
%   ITS PDU header (3 bytes, prepended by caller via BTP → GeoNet):
%     ProtocolVersion(1)=2 | MessageID_hi(1)=0 | MessageID_lo(1)=2
%     (StationID in CAM body)
%
%   Generating rate: typically 1-10 Hz (100-1000 ms period)
%   BTP destination port: 2001
%
%   References:
%     ETSI EN 302 637-2 v1.4.1 — CAM specification
%     ETSI TS 102 894-2 — ITS data dictionary

%   Copyright 2025. NR Sidelink Simulation Platform.

    properties (Constant)
        MESSAGE_ID       = uint16(2)   % CAM message ID
        PROTOCOL_VERSION = uint8(2)    % ETSI ITS protocol version
        PDU_SIZE_BYTES   = 30          % Compact binary PDU size
        BTP_PORT         = 2001        % BTP well-known port for CAM

        % Station types (ETSI TS 102 894-2)
        ST_UNKNOWN       = 0
        ST_PEDESTRIAN    = 1
        ST_CYCLIST       = 2
        ST_MOPED         = 3
        ST_MOTORCYCLE    = 4
        ST_PASSENGER_CAR = 5
        ST_BUS           = 6
        ST_LIGHT_TRUCK   = 7
        ST_HEAVY_TRUCK   = 8
        ST_TRAILER       = 9
        ST_SPECIAL_VEH   = 10
        ST_TRAM          = 11
        ST_RSU           = 15

        % Vehicle role (ETSI EN 302 637-2)
        ROLE_DEFAULT     = 0
        ROLE_PUBLIC_TR   = 1
        ROLE_SPECIAL_TR  = 2
        ROLE_DANGEROUS_G = 3
        ROLE_EMERGENCY   = 4
        ROLE_SAFETY_CAR  = 5
    end

    properties
        StationID    (1,1) uint32 = 0
        StationType  (1,1) uint8  = 5    % Default: passenger car
        VehicleRole  (1,1) uint8  = 0    % Default role
    end

    properties (SetAccess = private)
        TxCount      (1,1) uint32 = 0
        RxCount      (1,1) uint32 = 0
    end

    methods
        function obj = CAMGenerator(stationID, stationType)
        %CAMGenerator Construct for a given ITS station
        %   stationID:   unique 32-bit station identifier
        %   stationType: ITS station type (default: 5 = passenger car)
            if nargin < 1; stationID   = 0; end
            if nargin < 2; stationType = 5; end
            obj.StationID   = uint32(stationID);
            obj.StationType = uint8(stationType);
        end

        %% ----- TX -----

        function pdu = generateCAM(obj, vehicleState, currentTimeMs)
        %generateCAM Build a CAM PDU from vehicle state
        %   vehicleState: struct with fields:
        %     Lat_deg, Long_deg, Alt_m, Speed_ms, Heading_deg,
        %     Acceleration_ms2 (optional), YawRate_degs (optional)
        %   currentTimeMs: current simulation time in ms [default 0]
        %
        %   Returns uint8 byte vector (30 bytes).
            if nargin < 3; currentTimeMs = 0; end

            % Generation Delta Time: ms since last epoch start, mod 65536
            genDT = uint16(mod(round(currentTimeMs), 65536));

            % Encode fields
            lat_raw  = obj.encLat(vehicleState.Lat_deg);
            lon_raw  = obj.encLon(vehicleState.Long_deg);
            alt_raw  = obj.encAlt(vehicleState.Alt_m);
            spd_raw  = obj.encSpeed(vehicleState.Speed_ms);
            hdg_raw  = obj.encHeading(vehicleState.Heading_deg);

            if isfield(vehicleState, 'Acceleration_ms2')
                acc_raw = obj.encAccel(vehicleState.Acceleration_ms2);
            else
                acc_raw = int16(161);  % unavailable
            end
            curvMode = uint8(0);  % 0 = yaw rate used

            if isfield(vehicleState, 'YawRate_degs')
                yr_raw = obj.encYawRate(vehicleState.YawRate_degs);
            else
                yr_raw = int16(32767);  % unavailable
            end

            extLights = uint8(0);  % all off by default

            % Pack to bytes
            pdu = [ ...
                uint8(0), uint8(obj.MESSAGE_ID), ...          % MessageID
                obj.u32ToBytes(obj.StationID), ...             % StationID
                uint8(bitshift(genDT,-8)), uint8(genDT & 255),...% GenDeltaTime
                obj.StationType, ...                           % StationType
                obj.i32ToBytes(lat_raw), ...                   % Latitude
                obj.i32ToBytes(lon_raw), ...                   % Longitude
                obj.i16ToBytes(alt_raw), ...                   % Altitude
                uint8(bitshift(spd_raw,-8)), uint8(spd_raw & 255), ... % Speed
                uint8(bitshift(hdg_raw,-8)), uint8(hdg_raw & 255), ... % Heading
                obj.i16ToBytes(acc_raw), ...                   % LongAccel
                curvMode, ...                                  % CurvMode
                obj.i16ToBytes(yr_raw), ...                    % YawRate
                obj.VehicleRole, ...                           % VehicleRole
                extLights ...                                  % ExtLights
            ];

            obj.TxCount = obj.TxCount + 1;
        end

        %% ----- RX -----

        function cam = parseCAM(obj, pdu)
        %parseCAM Decode a received CAM PDU
        %   Returns struct with all decoded fields, or [] if malformed.
            cam = [];
            if isempty(pdu) || numel(pdu) < obj.PDU_SIZE_BYTES; return; end
            pdu = uint8(pdu(:)');

            cam.MessageID  = uint16(double(pdu(1))*256 + double(pdu(2)));
            if cam.MessageID ~= obj.MESSAGE_ID; cam = []; return; end

            cam.StationID  = obj.bytesToU32(pdu(3:6));
            cam.GenDeltaTime = uint16(double(pdu(7))*256 + double(pdu(8)));
            cam.StationType  = pdu(9);
            cam.Latitude_deg  = double(obj.bytesToI32(pdu(10:13))) * 1e-7;
            cam.Longitude_deg = double(obj.bytesToI32(pdu(14:17))) * 1e-7;
            cam.Altitude_m    = double(obj.bytesToI16(pdu(18:19))) * 0.01;
            cam.Speed_ms      = (double(pdu(20))*256 + double(pdu(21))) * 0.01;
            cam.Heading_deg   = (double(pdu(22))*256 + double(pdu(23))) * 0.1;
            cam.Acceleration_ms2 = double(obj.bytesToI16(pdu(24:25))) * 0.1;
            cam.CurvMode      = pdu(26);
            cam.YawRate_degs  = double(obj.bytesToI16(pdu(27:28))) * 0.01;
            cam.VehicleRole   = pdu(29);
            cam.ExteriorLights = pdu(30);

            obj.RxCount = obj.RxCount + 1;
        end

        function stats = getStats(obj)
        %getStats Return TX/RX statistics
            stats = struct('TxCAMs', obj.TxCount, 'RxCAMs', obj.RxCount);
        end

        function reset(obj)
            obj.TxCount = 0;
            obj.RxCount = 0;
        end
    end

    %% ----- Private encoding helpers -----
    methods (Access = private)

        function v = encLat(~, deg)
            % Latitude: 0.1 microdegree = 1e-7 degree resolution
            % Range: -900000000 to 900000001 (90 deg = 900000000)
            v = int32(max(-900000000, min(900000000, round(deg * 1e7))));
        end

        function v = encLon(~, deg)
            v = int32(max(-1800000000, min(1800000000, round(deg * 1e7))));
        end

        function v = encAlt(~, m)
            % Altitude: 0.01 m resolution, range -10000..80000 (−100m..800m)
            if isnan(m) || isinf(m); v = int16(-10000); return; end
            v = int16(max(-10000, min(800001, round(m * 100))));
        end

        function v = encSpeed(~, ms)
            % Speed: 0.01 m/s resolution, 0..16382, 16383=unavailable
            if isnan(ms) || ms < 0; v = uint16(16383); return; end
            v = uint16(min(16382, round(ms * 100)));
        end

        function v = encHeading(~, deg)
            % Heading: 0.1 degree, 0..3600, 3601=unavailable
            if isnan(deg); v = uint16(3601); return; end
            v = uint16(min(3600, round(mod(deg, 360) * 10)));
        end

        function v = encAccel(~, ms2)
            % Longitudinal accel: 0.1 m/s² resolution, ±160, 161=unavailable
            if isnan(ms2) || abs(ms2) > 16; v = int16(161); return; end
            v = int16(max(-160, min(160, round(ms2 * 10))));
        end

        function v = encYawRate(~, degs)
            % Yaw rate: 0.01 deg/s, ±32766, 32767=unavailable
            if isnan(degs); v = int16(32767); return; end
            v = int16(max(-32766, min(32766, round(degs * 100))));
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
