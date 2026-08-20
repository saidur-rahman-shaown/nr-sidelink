classdef BasicTransportProtocol < handle
%BasicTransportProtocol ETSI ITS-G5 BTP layer (EN 302 636-5-1)
%
%   Provides port-based demultiplexing between GeoNetworking and ITS
%   Facilities layer entities (CAM, DENM, MAPEM, SPATEM, etc.).
%
%   BTP-A Header (4 bytes, for connection-oriented services, used by CAM):
%     DestPort(16) | SrcPort(16)
%
%   BTP-B Header (4 bytes, for connectionless services, used by DENM):
%     DestPort(16) | DestPortInfo(16)
%
%   Well-known ITS-G5 port numbers (ETSI EN 302 636-5-1 Annex A):
%     2001  CAM   (Cooperative Awareness Message)
%     2002  DENM  (Decentralized Environmental Notification)
%     2003  MAPEM (Map Data)
%     2004  SPATEM (Signal Phase and Timing)
%     2005  SAEM  (Services Announcement)
%     2006  IVIM  (Infrastructure to Vehicle Information)
%     2007  SREM  (Signal Request Message)
%     2008  SSEM  (Signal Status Message)
%     2009  EVCSN (Electric Vehicle Charging Spot Notification)
%     2010  TISTPG (Tyre Information System)
%     2030  IMZM  (Intersection Management Zone)
%     17532 BSM   (Basic Safety Message, US J2945.1)
%
%   Usage:
%     btp = BasicTransportProtocol(geoNet);
%     pdu = btp.encapsulate(payload, 2001, 'A');   % BTP-A with dst=2001
%     pdu = btp.encapsulate(payload, 2002, 'B', extraInfo);
%     pkt = btp.decapsulate(btpPDU);               % Returns struct
%
%   References:
%     ETSI EN 302 636-5-1 v2.2.1 — ITS BTP

%   Copyright 2025. NR Sidelink Simulation Platform.

    properties (Constant)
        % Well-known port assignments
        PORT_CAM    = uint16(2001)
        PORT_DENM   = uint16(2002)
        PORT_MAPEM  = uint16(2003)
        PORT_SPATEM = uint16(2004)
        PORT_SAEM   = uint16(2005)
        PORT_IVIM   = uint16(2006)
        PORT_SREM   = uint16(2007)
        PORT_SSEM   = uint16(2008)
        PORT_EVCSN  = uint16(2009)

        BTP_TYPE_A = 'A'  % Connection-oriented (source port present)
        BTP_TYPE_B = 'B'  % Connectionless (dest port info present)
    end

    properties (SetAccess = private)
        GeoNet      % GeoNetworkingEntity reference

        % RX dispatch table: port → handler function handle
        Handlers    = struct()

        % Stats per port
        TxCounts    = struct()
        RxCounts    = struct()
    end

    methods
        function obj = BasicTransportProtocol(geoNet)
        %BasicTransportProtocol Construct with GeoNetworking reference
            obj.GeoNet = geoNet;
        end

        %% ----- TX -----

        function btpPDU = encapsulate(obj, payload, dstPort, btpType, portInfo)
        %encapsulate Build a BTP PDU from payload
        %   payload:  uint8 byte vector (ITS facility message)
        %   dstPort:  uint16 destination port
        %   btpType:  'A' or 'B' [default 'A']
        %   portInfo: (BTP-B only) destination port info [default 0]
        %
        %   Returns uint8 BTP PDU = 4-byte header + payload
            if nargin < 4; btpType  = 'A'; end
            if nargin < 5; portInfo = uint16(0); end
            payload  = uint8(payload(:)');
            dstPort  = uint16(dstPort);
            portInfo = uint16(portInfo);

            dpHi = uint8(bitshift(dstPort,-8));
            dpLo = uint8(dstPort & 255);
            piHi = uint8(bitshift(portInfo,-8));
            piLo = uint8(portInfo & 255);

            btpPDU = [dpHi, dpLo, piHi, piLo, payload];

            % Update TX stats
            portKey = sprintf('p%u', dstPort);
            if isfield(obj.TxCounts, portKey)
                obj.TxCounts.(portKey) = obj.TxCounts.(portKey) + 1;
            else
                obj.TxCounts.(portKey) = 1;
            end
        end

        %% ----- RX -----

        function pkt = decapsulate(obj, btpPDU)
        %decapsulate Parse a received BTP PDU
        %   Returns struct with: dstPort, srcPortOrInfo, payload, btpType
        %   Returns [] if malformed.
            pkt = [];
            if isempty(btpPDU) || numel(btpPDU) < 4; return; end
            btpPDU = uint8(btpPDU(:)');

            dstPort  = uint16(double(btpPDU(1)) * 256 + double(btpPDU(2)));
            portInfo = uint16(double(btpPDU(3)) * 256 + double(btpPDU(4)));
            payload  = btpPDU(5:end);

            % Detect BTP type: BTP-B uses source port = 0 (no source port)
            % In practice both have same header; we determine by registered port
            btpType = 'A';
            if dstPort == obj.PORT_DENM || dstPort == obj.PORT_MAPEM || ...
               dstPort == obj.PORT_SPATEM
                btpType = 'B';
            end

            pkt = struct( ...
                'dstPort',  dstPort, ...
                'portInfo', portInfo, ...
                'btpType',  btpType, ...
                'payload',  payload);

            % Update RX stats
            portKey = sprintf('p%u', dstPort);
            if isfield(obj.RxCounts, portKey)
                obj.RxCounts.(portKey) = obj.RxCounts.(portKey) + 1;
            else
                obj.RxCounts.(portKey) = 1;
            end

            % Dispatch to registered handler if any
            obj.dispatch(pkt);
        end

        %% ----- Handler registration -----

        function registerHandler(obj, port, handlerFn)
        %registerHandler Register a callback for a specific BTP port
        %   port:      uint16 port number
        %   handlerFn: function handle f(pkt) called on reception
            portKey = sprintf('p%u', port);
            obj.Handlers.(portKey) = handlerFn;
        end

        function removeHandler(obj, port)
        %removeHandler Remove handler for a port
            portKey = sprintf('p%u', port);
            if isfield(obj.Handlers, portKey)
                obj.Handlers = rmfield(obj.Handlers, portKey);
            end
        end

        %% ----- Stats -----

        function stats = getStats(obj)
        %getStats Return per-port TX/RX statistics
            stats = struct('TxByPort', obj.TxCounts, 'RxByPort', obj.RxCounts);
        end

        function reset(obj)
            obj.TxCounts = struct();
            obj.RxCounts = struct();
        end
    end

    methods (Access = private)
        function dispatch(obj, pkt)
            portKey = sprintf('p%u', pkt.dstPort);
            if isfield(obj.Handlers, portKey)
                fn = obj.Handlers.(portKey);
                try; fn(pkt); catch; end
            end
        end
    end
end
