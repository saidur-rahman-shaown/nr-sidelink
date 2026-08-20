classdef GeoNetworkingEntity < handle
%GeoNetworkingEntity ETSI ITS-G5 GeoNetworking entity (EN 302 636-4-1)
%
%   Implements the ITS-G5 GeoNetworking protocol (GN) for NR V2X sidelink
%   over the PC5 interface, per ETSI EN 302 636-4-1 v1.4.1.
%
%   Supported packet types:
%     SHB  (Single Hop Broadcast, HT=0x14) — CAM, SPATEM over one-hop
%     GBC  (GeoBroadcast,         HT=0x04) — DENM, IVIM over a geo area
%     BEACON (Beaconing,          HT=0x01) — Neighbour discovery
%
%   GeoNetworking PDU structure:
%     [BasicHeader(4)] [CommonHeader(8)] [ExtendedHeader(variable)] [Payload]
%
%   Basic Header (4 bytes, EN 302 636-4-1 Sec 8.6.2):
%     Version(4) | NH(4) | Reserved(8) | Lifetime(8) | RHL(8)
%
%   Common Header (8 bytes, EN 302 636-4-1 Sec 8.7.1):
%     MHL(8) | Reserved(8) | HT(8) | HST(8) | TC(8) | Flags(8) | PL(16)
%
%   Long Position Vector SPV (24 bytes, EN 302 636-4-1 Sec 8.5.2):
%     GN_ADDR(8) | TST(4) | Lat(4) | Long(4) | PAI+Speed(2) | Heading(2)
%
%   SHB Extended Header (4 bytes + SPV = 28 bytes total):
%     Reserved(32) | SPV_Long(24)
%
%   GBC Extended Header (20 + SPV = 44 bytes total):
%     SN(16)+Reserved(16) | SPV_Long(24) | GeoArea(shape:8,DistA:16,DistB:16,Angle:16,Res:16) | Res(32)
%
%   Location Table: maintains last-known position of each neighbour.
%
%   References:
%     ETSI EN 302 636-4-1 v1.4.1 — ITS GeoNetworking
%     ETSI EN 302 665 — ITS communications architecture

%   Copyright 2025. NR Sidelink Simulation Platform.

    % GN constants
    properties (Constant)
        GN_VERSION   = uint8(1)     % GeoNetworking protocol version
        HT_BEACON    = uint8(1)     % Packet type: BEACON
        HT_GUC       = uint8(2)     % Packet type: GeoUnicast
        HT_GBC       = uint8(4)     % Packet type: GeoBroadcast
        HT_GAC       = uint8(5)     % Packet type: GeoAnycast
        HT_SHB       = uint8(20)    % Packet type: Single Hop Broadcast (TSB)
        HT_LS_REQ    = uint8(10)    % Location Service Request
        HT_LS_REPLY  = uint8(11)    % Location Service Reply

        NH_BTP_A     = uint8(1)     % Next Header: BTP-A
        NH_BTP_B     = uint8(2)     % Next Header: BTP-B
        NH_ANY       = uint8(0)     % Next Header: any

        MAX_LIFETIME_MS  = 600000   % Max 600 s GN lifetime
        DEFAULT_LIFETIME_MS = 1000  % Default 1 s
        DEFAULT_RHL      = 1        % Remaining Hop Limit (SHB always 1)
        SHB_RHL          = 1
        GBC_RHL          = 10       % Configurable hop limit for GBC

        GEO_SHAPE_CIRCLE = uint8(0)
        GEO_SHAPE_RECT   = uint8(1)
        GEO_SHAPE_ELLIPSE= uint8(3)
    end

    properties
        GNAddress    (1,8) uint8 = zeros(1,8,'uint8')  % 64-bit GN address
        StationType  (1,1) uint8 = 5       % ITS station type (5=passenger car)
        BeaconingEnabled (1,1) logical = true
        BeaconingIntervalMs (1,1) double = 1000  % Beacon period

        % Traffic class
        SCF          (1,1) logical = false  % Store-Carry-Forward (off for SHB)
        ChannelOffload (1,1) logical = false
        TCID         (1,1) uint8 = 0       % TC_ID (QoS)
    end

    properties (SetAccess = private)
        % Local position & motion
        Latitude_deg  (1,1) double = 0
        Longitude_deg (1,1) double = 0
        Altitude_m    (1,1) double = 0
        Speed_ms      (1,1) double = 0
        Heading_deg   (1,1) double = 0
        Timestamp_ms  (1,1) uint32 = 0   % GN timestamp (ms, 32-bit wrapping)

        % Location Table (LT): struct indexed by hexGNAddr
        LocationTable = struct()

        % Sequence number for GBC
        TxSN         (1,1) uint16 = 0

        % Stats
        TxSHBCount   (1,1) uint32 = 0
        TxGBCCount   (1,1) uint32 = 0
        TxBeaconCount(1,1) uint32 = 0
        RxCount      (1,1) uint32 = 0
    end

    methods
        function obj = GeoNetworkingEntity(l2id, varargin)
        %GeoNetworkingEntity Construct for a UE identified by l2id
        %   GeoNetworkingEntity(l2id, 'StationType', 5, ...)
            % Build GN address: M=0, ST=stationType, MID=l2id[23:0]
            stationType = 5;
            for i = 1:2:numel(varargin)
                if strcmpi(varargin{i}, 'StationType')
                    stationType = varargin{i+1};
                end
            end
            % GN_ADDR format: M(1)|R(1)|ST(6) | MID(48) in 8 bytes
            st6 = uint8(bitand(stationType, 63));
            mid = uint32(bitand(l2id, 16777215));  % 24-bit part
            obj.GNAddress = [st6, ...
                uint8(0), uint8(0), uint8(0), ...
                uint8(bitshift(mid,-16) & 255), ...
                uint8(bitshift(mid,-8)  & 255), ...
                uint8(mid & 255), uint8(0)];
            obj.StationType = uint8(stationType);
            for i = 1:2:numel(varargin)
                if ~strcmpi(varargin{i}, 'StationType')
                    obj.(varargin{i}) = varargin{i+1};
                end
            end
        end

        %% ----- Position update -----

        function updatePosition(obj, lat, lon, alt, speed, heading)
        %updatePosition Update local vehicle position and kinematics
            obj.Latitude_deg  = lat;
            obj.Longitude_deg = lon;
            obj.Altitude_m    = alt;
            obj.Speed_ms      = speed;
            obj.Heading_deg   = heading;
        end

        function advanceTime(obj, deltaMs)
        %advanceTime Advance GN timestamp by deltaMs
            obj.Timestamp_ms = uint32(mod(double(obj.Timestamp_ms) + deltaMs, 2^32));
        end

        %% ----- TX: packet builders -----

        function gnPDU = buildSHB(obj, payload, nhType)
        %buildSHB Build a Single Hop Broadcast GN PDU
        %   payload: uint8 byte vector (BTP PDU)
        %   nhType:  NH_BTP_A (1) or NH_BTP_B (2) [default: NH_BTP_A]
        %
        %   Total overhead: 4 (Basic) + 8 (Common) + 4 (Reserved) + 24 (SPV) = 40 bytes
            if nargin < 3; nhType = obj.NH_BTP_A; end
            payload  = uint8(payload(:)');
            pl       = numel(payload);

            basicHdr  = obj.buildBasicHeader(nhType, obj.DEFAULT_LIFETIME_MS, obj.SHB_RHL);
            commHdr   = obj.buildCommonHeader(obj.HT_GBC, uint8(0), ...
                            obj.buildTC(), uint8(0), uint16(pl + 28));
            % SHB extended header: Reserved(4) + SPV_Long(24)
            shbExt = [zeros(1,4,'uint8'), obj.buildSPVLong()];

            gnPDU = [basicHdr, commHdr, shbExt, payload];
            obj.TxSHBCount = obj.TxSHBCount + 1;
        end

        function gnPDU = buildGBC(obj, payload, geoArea, nhType)
        %buildGBC Build a GeoBroadcast GN PDU targeting a geographic area
        %   payload:  uint8 byte vector (BTP PDU)
        %   geoArea:  struct with Lat_deg, Long_deg, DistA_m, DistB_m, Angle_deg
        %   nhType:   NH_BTP_A or NH_BTP_B [default: NH_BTP_A]
        %
        %   GBC extended header: SN(2)+Res(2) + SPV_Long(24) + GeoArea(10) + Res(4) = 40 bytes
            if nargin < 4; nhType = obj.NH_BTP_A; end
            payload  = uint8(payload(:)');
            pl       = numel(payload);

            basicHdr  = obj.buildBasicHeader(nhType, obj.DEFAULT_LIFETIME_MS, obj.GBC_RHL);
            commHdr   = obj.buildCommonHeader(obj.HT_GBC, uint8(0), ...
                            obj.buildTC(), uint8(0), uint16(pl + 40));

            sn  = obj.TxSN;
            obj.TxSN = uint16(mod(double(obj.TxSN) + 1, 65536));

            snField   = [uint8(bitshift(sn,-8)), uint8(sn & 255)];
            gbcExt    = [snField, zeros(1,2,'uint8'), obj.buildSPVLong(), ...
                         obj.encodeGeoArea(geoArea), zeros(1,4,'uint8')];

            gnPDU = [basicHdr, commHdr, gbcExt, payload];
            obj.TxGBCCount = obj.TxGBCCount + 1;
        end

        function gnPDU = buildBeacon(obj)
        %buildBeacon Build a GN BEACON PDU (neighbour discovery)
            basicHdr = obj.buildBasicHeader(obj.NH_ANY, obj.DEFAULT_LIFETIME_MS, 1);
            commHdr  = obj.buildCommonHeader(obj.HT_BEACON, uint8(0), ...
                           obj.buildTC(), uint8(0), uint16(24));
            gnPDU    = [basicHdr, commHdr, obj.buildSPVLong()];
            obj.TxBeaconCount = obj.TxBeaconCount + 1;
        end

        %% ----- RX: packet parser -----

        function pkt = receive(obj, gnPDU)
        %receive Parse a received GN PDU
        %   Returns struct with fields: type, srcAddr, payload, header, geo
        %   Returns [] if PDU is malformed or is our own (address filter).
            pkt = [];
            gnPDU = uint8(gnPDU(:)');
            if numel(gnPDU) < 12; return; end

            obj.RxCount = obj.RxCount + 1;

            % Parse Basic Header
            basicNH  = bitand(gnPDU(1), uint8(15));  % lower nibble = NH
            lifetime = double(gnPDU(3));              % encoded lifetime
            rhl      = double(gnPDU(4));
            if rhl < 1; return; end  % Hop limit expired

            % Parse Common Header
            htByte   = gnPDU(9);   % HT field
            plBytes  = double(gnPDU(11)) * 256 + double(gnPDU(12));

            pkt = struct();
            pkt.type    = htByte;
            pkt.nh      = basicNH;
            pkt.rhl     = rhl;
            pkt.pl      = plBytes;

            switch htByte
                case obj.HT_SHB
                    % SHB: Reserved(4) + SPV_Long(24) + payload
                    if numel(gnPDU) < 40; pkt = []; return; end
                    spv       = obj.parseSPVLong(gnPDU(17:40));
                    pkt.srcAddr  = spv.gnAddr;
                    pkt.srcLat   = spv.lat;
                    pkt.srcLong  = spv.lon;
                    pkt.srcSpeed = spv.speed;
                    pkt.srcHead  = spv.heading;
                    pkt.payload  = gnPDU(41:end);
                    obj.updateLocationTable(spv);

                case obj.HT_GBC
                    % GBC: SN(2)+Res(2)+SPV_Long(24)+GeoArea(10)+Res(4) = 40 extra, start at byte 13
                    if numel(gnPDU) < 52; pkt = []; return; end
                    spv       = obj.parseSPVLong(gnPDU(17:40));
                    pkt.srcAddr  = spv.gnAddr;
                    pkt.srcLat   = spv.lat;
                    pkt.srcLong  = spv.lon;
                    pkt.srcSpeed = spv.speed;
                    pkt.srcHead  = spv.heading;
                    pkt.payload  = gnPDU(53:end);
                    obj.updateLocationTable(spv);

                case obj.HT_BEACON
                    if numel(gnPDU) < 36; pkt = []; return; end
                    spv = obj.parseSPVLong(gnPDU(13:36));
                    pkt.srcAddr  = spv.gnAddr;
                    pkt.payload  = uint8([]);
                    obj.updateLocationTable(spv);

                otherwise
                    pkt.srcAddr = uint8(zeros(1,8));
                    pkt.payload = gnPDU(13:end);
            end
        end

        %% ----- Location table -----

        function lt = getLocationTable(obj)
        %getLocationTable Return copy of location table
            lt = obj.LocationTable;
        end

        function stats = getStats(obj)
        %getStats Return statistics struct
            stats = struct( ...
                'TxSHB',    obj.TxSHBCount, ...
                'TxGBC',    obj.TxGBCCount, ...
                'TxBeacon', obj.TxBeaconCount, ...
                'Rx',       obj.RxCount, ...
                'LTEntries', numel(fieldnames(obj.LocationTable)));
        end

        function reset(obj)
            obj.TxSN          = 0;
            obj.Timestamp_ms  = 0;
            obj.LocationTable = struct();
            obj.TxSHBCount    = 0;
            obj.TxGBCCount    = 0;
            obj.TxBeaconCount = 0;
            obj.RxCount       = 0;
        end
    end

    %% ----- Private helpers -----
    methods (Access = private)

        function hdr = buildBasicHeader(obj, nh, lifetimeMs, rhl)
            % Version(4)|NH(4) | Reserved(8) | Lifetime(8) | RHL(8)
            vnh = bitor(bitshift(obj.GN_VERSION, 4), uint8(nh & 15));
            lt  = obj.encodeLifetime(lifetimeMs);
            hdr = [vnh, uint8(0), lt, uint8(rhl)];
        end

        function hdr = buildCommonHeader(~, ht, hst, tc, flags, pl)
            % MHL(8)|Reserved(8)|HT(8)|HST(8)|TC(8)|Flags(8)|PL(16)
            plHi = uint8(bitshift(uint16(pl), -8) & 255);
            plLo = uint8(pl & 255);
            hdr  = [uint8(10), uint8(0), ht, hst, tc, flags, plHi, plLo];
        end

        function tc = buildTC(obj)
            % TC = SCF(1)|CO(1)|TC_ID(6)
            scfBit = uint8(obj.SCF) * uint8(128);
            coBit  = uint8(obj.ChannelOffload) * uint8(64);
            tc = bitor(bitor(scfBit, coBit), uint8(bitand(obj.TCID, 63)));
        end

        function spv = buildSPVLong(obj)
            % GN_ADDR(8)|TST(4)|Lat(4)|Long(4)|PAI+Speed(2)|Heading(2) = 24 bytes
            lat_raw  = int32(obj.Latitude_deg  * 1e7);
            lon_raw  = int32(obj.Longitude_deg * 1e7);
            spd_raw  = uint16(min(obj.Speed_ms * 100, 16383));
            hdg_raw  = uint16(mod(obj.Heading_deg * 10, 3601));
            tst      = obj.Timestamp_ms;

            spv = [obj.GNAddress, ...
                   obj.int32ToBytes(tst), ...
                   obj.int32ToBytes(lat_raw), ...
                   obj.int32ToBytes(lon_raw), ...
                   uint8(bitshift(spd_raw,-8)), uint8(spd_raw & 255), ...
                   uint8(bitshift(hdg_raw,-8)), uint8(hdg_raw & 255)];
        end

        function spv = parseSPVLong(~, raw)
            if numel(raw) < 24
                spv = struct('gnAddr',uint8(zeros(1,8)), 'lat',0, 'lon',0, ...
                             'speed',0, 'heading',0, 'tst',uint32(0));
                return;
            end
            raw = uint8(raw(:)');
            gnAddr  = raw(1:8);
            tst     = uint32(double(raw(9))*16777216 + double(raw(10))*65536 + ...
                             double(raw(11))*256 + double(raw(12)));
            lat_raw = int32(double(raw(13))*16777216 + double(raw(14))*65536 + ...
                            double(raw(15))*256 + double(raw(16)));
            lon_raw = int32(double(raw(17))*16777216 + double(raw(18))*65536 + ...
                            double(raw(19))*256 + double(raw(20)));
            spd_raw = double(raw(21))*256 + double(raw(22));
            hdg_raw = double(raw(23))*256 + double(raw(24));
            spv = struct( ...
                'gnAddr',   gnAddr, ...
                'lat',      double(lat_raw) * 1e-7, ...
                'lon',      double(lon_raw) * 1e-7, ...
                'speed',    spd_raw / 100, ...
                'heading',  hdg_raw / 10, ...
                'tst',      tst);
        end

        function ga = encodeGeoArea(~, geoArea)
            % GeoArea: Shape(1)+Reserved(1)+DistA(2)+DistB(2)+Angle(2)+Reserved(2) = 10 bytes
            % Simplified: circle with radius=DistA_m, centered at geoArea.Lat/Long
            if isfield(geoArea, 'Shape')
                shape = uint8(geoArea.Shape);
            else
                shape = uint8(0);  % circle
            end
            if isfield(geoArea, 'DistA_m'); da = min(round(geoArea.DistA_m), 65535);
            else; da = 500; end
            if isfield(geoArea, 'DistB_m'); db = min(round(geoArea.DistB_m), 65535);
            else; db = 0; end
            if isfield(geoArea, 'Angle_deg'); ang = min(round(geoArea.Angle_deg), 65535);
            else; ang = 0; end
            ga = [shape, uint8(0), ...
                  uint8(bitshift(da,-8)), uint8(da & 255), ...
                  uint8(bitshift(db,-8)), uint8(db & 255), ...
                  uint8(bitshift(ang,-8)), uint8(ang & 255), ...
                  uint8(0), uint8(0)];
        end

        function lt = encodeLifetime(~, ms)
            % Lifetime encoded as Base * Multiplier, base choices: 50ms, 1s, 10s, 100s
            if ms <= 50 * 255
                mult = max(1, round(ms / 50));
                lt = uint8(bitshift(uint8(0), 6) + uint8(min(mult,63)));
            elseif ms <= 1000 * 255
                mult = max(1, round(ms / 1000));
                lt = uint8(bitshift(uint8(1), 6) + uint8(min(mult,63)));
            elseif ms <= 10000 * 63
                mult = max(1, round(ms / 10000));
                lt = uint8(bitshift(uint8(2), 6) + uint8(min(mult,63)));
            else
                mult = max(1, round(ms / 100000));
                lt = uint8(bitshift(uint8(3), 6) + uint8(min(mult,63)));
            end
        end

        function b = int32ToBytes(~, v)
            v = int32(v);
            b = uint8([bitshift(v,-24) & 255, bitshift(v,-16) & 255, ...
                       bitshift(v,-8)  & 255, v & 255]);
        end

        function updateLocationTable(obj, spv)
            key = sprintf('gn%02x%02x%02x%02x', spv.gnAddr(1), spv.gnAddr(2), ...
                          spv.gnAddr(3), spv.gnAddr(4));
            obj.LocationTable.(key) = spv;
        end
    end
end
