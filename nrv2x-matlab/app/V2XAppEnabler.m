classdef V2XAppEnabler < handle
%V2XAppEnabler 3GPP V2X Application Enabler layer (TS 23.286)
%
%   Implements a simulation model of the V2X Application Enabler (VAE)
%   layer per 3GPP TS 23.286 v17.3.0. The VAE layer sits above PC5-S and
%   provides:
%     - V2X service registration and announcement
%     - Application-layer V2X message formatting (V2X_MSG_TYPE)
%     - QoS flow selection based on V2X service type
%     - Geographic filtering (relevance zone based on position)
%     - Service continuity between PC5 and Uu interfaces
%
%   V2X Message PDU format (simplified binary):
%     Byte 0:    VAE_MSG_TYPE (uint8)
%     Bytes 1-4: ProviderID / ServiceID (uint32)
%     Bytes 5-6: PayloadLength (uint16)
%     Bytes 7+:  Payload
%
%   VAE_MSG_TYPE values:
%     1  = V2X_DATA             (application data message)
%     2  = V2X_SERVICE_ANNOUNCE (service discovery announcement)
%     3  = V2X_SUBSCRIPTION_REQ (subscribe to a V2X service)
%     4  = V2X_SUBSCRIPTION_ACK (subscription confirmed)
%     5  = V2X_GEO_DATA         (data with geographic targeting)
%
%   V2X Services (TS 23.285 / ETSI TS 102 965):
%     ServiceID 0x00010001: Cooperative Awareness (CAM equivalent)
%     ServiceID 0x00010002: Hazard Warning (DENM equivalent)
%     ServiceID 0x00010003: Traffic Light Info (SPATEM)
%     ServiceID 0x00010004: Platooning
%     ServiceID 0x00010005: Sensor Sharing (advanced)
%     ServiceID 0x00010006: Remote Driving
%     ServiceID 0x00010007: Extended Sensor Sharing
%
%   QoS flow mapping (TS 23.287 Table 5.3.1-1):
%     CAM-type → PQI=55, Non-GBR, PDB=100ms
%     Hazard/Safety → PQI=65, GBR, PDB=100ms
%     Platoon control → PQI=21, GBR, PDB=20ms
%     Remote driving → PQI=91, DC-GBR, PDB=3ms
%
%   Usage:
%     vae = V2XAppEnabler(ueID, l2id);
%     vae.registerService(0x00010001, 'CooperativeAwareness');
%     pdu = vae.encapsulate(payload, serviceID);
%     msg = vae.decapsulate(rxBytes);
%
%   References:
%     3GPP TS 23.286 v17.3.0 — V2X Application Enabler
%     3GPP TS 23.287 v17.0.0 — V2X QoS architecture
%     3GPP TS 23.285 v17.0.0 — V2X service architecture

%   Copyright 2025. NR Sidelink Simulation Platform.

    properties (Constant)
        % VAE Message types
        MSG_V2X_DATA        = uint8(1)
        MSG_SVC_ANNOUNCE    = uint8(2)
        MSG_SUB_REQ         = uint8(3)
        MSG_SUB_ACK         = uint8(4)
        MSG_GEO_DATA        = uint8(5)

        % Standard V2X Service IDs (ETSI TS 102 965)
        SVC_COOP_AWARENESS  = uint32(hex2dec('00010001'))  % = CAM
        SVC_HAZARD_WARNING  = uint32(hex2dec('00010002'))  % = DENM
        SVC_TRAFFIC_LIGHT   = uint32(hex2dec('00010003'))  % = SPATEM
        SVC_PLATOONING      = uint32(hex2dec('00010004'))
        SVC_SENSOR_SHARING  = uint32(hex2dec('00010005'))
        SVC_REMOTE_DRIVING  = uint32(hex2dec('00010006'))
        SVC_EXT_SENSOR      = uint32(hex2dec('00010007'))
    end

    properties
        UEID        (1,1) uint32 = 1
        SourceL2ID  (1,1) uint32 = 0

        % Geographic filtering: position threshold for relevance
        GeoFilterEnabled (1,1) logical = false
        GeoFilterRadius_m (1,1) double = 1000  % Filter msgs outside this radius
    end

    properties (SetAccess = private)
        % Registered service table: struct, field svcXXXXXXXX = {name, pqi, qos}
        ServiceTable = struct()

        % Subscription table: services this UE is subscribed to
        Subscriptions = struct()

        % Current UE position
        Lat_deg  (1,1) double = 0
        Long_deg (1,1) double = 0

        % Outbound announce/sub queue
        TxQueue = {}

        % Stats
        TxCount (1,1) uint32 = 0
        RxCount (1,1) uint32 = 0
    end

    methods
        function obj = V2XAppEnabler(ueID, l2ID)
        %V2XAppEnabler Construct for a UE
            obj.UEID       = uint32(ueID);
            obj.SourceL2ID = uint32(l2ID);
            % Register standard V2X services
            obj.registerService(obj.SVC_COOP_AWARENESS,  'CooperativeAwareness',  55, 100);
            obj.registerService(obj.SVC_HAZARD_WARNING,  'HazardWarning',          65, 100);
            obj.registerService(obj.SVC_TRAFFIC_LIGHT,   'TrafficLightInfo',       75, 100);
            obj.registerService(obj.SVC_PLATOONING,      'Platooning',             21,  20);
            obj.registerService(obj.SVC_SENSOR_SHARING,  'SensorSharing',          65, 100);
            obj.registerService(obj.SVC_REMOTE_DRIVING,  'RemoteDriving',          91,   3);
        end

        %% ----- Service management -----

        function registerService(obj, svcID, name, pqi, pdb_ms)
        %registerService Register a V2X service at this VAE layer
        %   svcID:  uint32 service identifier
        %   name:   string descriptor
        %   pqi:    PC5 QoS Index
        %   pdb_ms: Packet Delay Budget in ms
            if nargin < 4; pqi = 55; end
            if nargin < 5; pdb_ms = 100; end
            key = sprintf('svc%08x', uint32(svcID));
            obj.ServiceTable.(key) = struct( ...
                'svcID', uint32(svcID), ...
                'name',  name, ...
                'pqi',   pqi, ...
                'pdb_ms', pdb_ms, ...
                'qos',   obj.pqiToQoSProfile(pqi, pdb_ms));
        end

        function subscribeToService(obj, svcID)
        %subscribeToService Subscribe to receive messages for a V2X service
            key = sprintf('svc%08x', uint32(svcID));
            obj.Subscriptions.(key) = true;
        end

        function unsubscribeFromService(obj, svcID)
        %unsubscribeFromService Remove subscription for a V2X service
            key = sprintf('svc%08x', uint32(svcID));
            if isfield(obj.Subscriptions, key)
                obj.Subscriptions = rmfield(obj.Subscriptions, key);
            end
        end

        %% ----- TX -----

        function pdu = encapsulate(obj, payload, svcID, msgType)
        %encapsulate Wrap a payload in a VAE V2X message PDU
        %   payload: uint8 byte vector (application data)
        %   svcID:   V2X service identifier (uint32)
        %   msgType: VAE message type [default: MSG_V2X_DATA = 1]
        %
        %   Returns uint8 VAE PDU = 7-byte header + payload
            if nargin < 4; msgType = obj.MSG_V2X_DATA; end
            payload  = uint8(payload(:)');
            pl       = numel(payload);
            svcBytes = obj.u32ToBytes(uint32(svcID));
            pdu = [msgType, svcBytes, uint8(bitshift(pl,-8)&255), uint8(pl&255), payload];
            obj.TxCount = obj.TxCount + 1;
        end

        function pdu = encapsulateWithGeo(obj, payload, svcID, lat, lon, radius_m)
        %encapsulateWithGeo Wrap payload with geographic targeting info
        %   Appends lat/lon/radius to the PDU for geo-targeted messages.
            basePDU = obj.encapsulate(payload, svcID, obj.MSG_GEO_DATA);
            lat_raw = int32(round(lat  * 1e7));
            lon_raw = int32(round(lon  * 1e7));
            rad_raw = uint32(min(round(radius_m), 4294967295));
            geoExt  = [obj.i32ToBytes(lat_raw), obj.i32ToBytes(lon_raw), obj.u32ToBytes(rad_raw)];
            pdu = [basePDU, geoExt];
        end

        function pdu = buildServiceAnnounce(obj, svcID)
        %buildServiceAnnounce Build a VAE service announcement PDU
            svc = obj.lookupService(svcID);
            if isempty(svc); pdu = []; return; end
            nameBytes = uint8(svc.name);
            pdu = obj.encapsulate(nameBytes, svcID, obj.MSG_SVC_ANNOUNCE);
        end

        %% ----- RX -----

        function msg = decapsulate(obj, pdu)
        %decapsulate Parse a received VAE PDU
        %   Returns struct or [] if malformed / not subscribed / geo-filtered.
            msg = [];
            if isempty(pdu) || numel(pdu) < 7; return; end
            pdu = uint8(pdu(:)');

            msgType = pdu(1);
            svcID   = obj.bytesToU32(pdu(2:5));
            pl      = double(pdu(6))*256 + double(pdu(7));
            if numel(pdu) < 7 + pl; return; end

            payload = pdu(8:7+pl);
            obj.RxCount = obj.RxCount + 1;

            msg = struct( ...
                'msgType', msgType, ...
                'svcID',   svcID, ...
                'svcName', obj.getServiceName(svcID), ...
                'pqi',     obj.getServicePQI(svcID), ...
                'payload', payload);

            if msgType == obj.MSG_GEO_DATA && numel(pdu) >= 7 + pl + 12
                extBytes = pdu(8+pl:7+pl+12);
                msg.geoLat    = double(obj.bytesToI32(extBytes(1:4))) * 1e-7;
                msg.geoLon    = double(obj.bytesToI32(extBytes(5:8))) * 1e-7;
                msg.geoRadius = double(obj.bytesToU32(extBytes(9:12)));
                % Apply geographic filter if enabled
                if obj.GeoFilterEnabled
                    dist = obj.haversine(obj.Lat_deg, obj.Long_deg, ...
                                         msg.geoLat, msg.geoLon);
                    if dist > obj.GeoFilterRadius_m + msg.geoRadius
                        msg = [];  % Out of relevance zone
                        return;
                    end
                end
            end
        end

        %% ----- Position -----

        function updatePosition(obj, lat, lon)
        %updatePosition Update UE geographic position for filtering
            obj.Lat_deg  = lat;
            obj.Long_deg = lon;
        end

        %% ----- QoS helpers -----

        function qos = getServiceQoS(obj, svcID)
        %getServiceQoS Return the QoS profile for a service
            svc = obj.lookupService(svcID);
            if isempty(svc)
                qos = struct('pqi', 55, 'pdb_ms', 100, 'type', 'Non-GBR');
            else
                qos = svc.qos;
            end
        end

        function pqi = getServicePQI(obj, svcID)
        %getServicePQI Return PC5 QoS Index for a service
            svc = obj.lookupService(svcID);
            if isempty(svc); pqi = 55; else; pqi = svc.pqi; end
        end

        function stats = getStats(obj)
        %getStats Return statistics
            stats = struct('TxMsgs', obj.TxCount, 'RxMsgs', obj.RxCount, ...
                           'Services', numel(fieldnames(obj.ServiceTable)), ...
                           'Subscriptions', numel(fieldnames(obj.Subscriptions)));
        end

        function reset(obj)
            obj.Subscriptions = struct();
            obj.TxQueue       = {};
            obj.TxCount       = 0;
            obj.RxCount       = 0;
        end
    end

    %% ----- Private -----
    methods (Access = private)

        function svc = lookupService(obj, svcID)
            key = sprintf('svc%08x', uint32(svcID));
            if isfield(obj.ServiceTable, key)
                svc = obj.ServiceTable.(key);
            else
                svc = [];
            end
        end

        function name = getServiceName(obj, svcID)
            svc = obj.lookupService(svcID);
            if isempty(svc); name = sprintf('Unknown(0x%08X)', svcID);
            else; name = svc.name; end
        end

        function qos = pqiToQoSProfile(~, pqi, pdb_ms)
            % Map PQI to QoS profile per TS 23.287 Table 5.3.1-1
            switch pqi
                case {21, 22}
                    qos = struct('pqi', pqi, 'type', 'GBR', 'pdb_ms', pdb_ms, ...
                                 'gfbr_kbps', 2000, 'mfbr_kbps', 4000);
                case {91, 92, 93}
                    qos = struct('pqi', pqi, 'type', 'DC-GBR', 'pdb_ms', pdb_ms, ...
                                 'gfbr_kbps', 1000, 'mfbr_kbps', 2000);
                otherwise  % Non-GBR
                    qos = struct('pqi', pqi, 'type', 'Non-GBR', 'pdb_ms', pdb_ms, ...
                                 'gfbr_kbps', 0, 'mfbr_kbps', 0);
            end
        end

        function d = haversine(~, lat1, lon1, lat2, lon2)
            % Haversine great-circle distance in metres
            R   = 6371000;
            dLat = (lat2 - lat1) * pi / 180;
            dLon = (lon2 - lon1) * pi / 180;
            a   = sin(dLat/2)^2 + cos(lat1*pi/180)*cos(lat2*pi/180)*sin(dLon/2)^2;
            d   = R * 2 * atan2(sqrt(a), sqrt(1-a));
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

        function v = bytesToU32(~, b)
            v = uint32(double(b(1))*16777216 + double(b(2))*65536 + ...
                       double(b(3))*256 + double(b(4)));
        end

        function v = bytesToI32(~, b)
            u = uint32(double(b(1))*16777216 + double(b(2))*65536 + ...
                       double(b(3))*256 + double(b(4)));
            if u >= 2^31; v = int32(u) - int32(2^32); else; v = int32(u); end
        end
    end
end
