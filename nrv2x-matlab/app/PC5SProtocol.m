classdef PC5SProtocol < handle
%PC5SProtocol 3GPP PC5-S Protocol for NR V2X sidelink (TS 24.386)
%
%   Implements the PC5 Signalling (PC5-S) protocol used to establish,
%   manage, and release PC5 unicast links between NR V2X UEs per
%   3GPP TS 24.386 v17.4.0.
%
%   PC5-S message types (TS 24.386 Section 9):
%     Type 1:  DIRECT_COMMUNICATION_REQUEST
%     Type 2:  DIRECT_COMMUNICATION_ACCEPT
%     Type 3:  DIRECT_COMMUNICATION_REJECT
%     Type 4:  DIRECT_COMMUNICATION_KEEPALIVE
%     Type 5:  DIRECT_COMMUNICATION_KEEPALIVE_ACK
%     Type 6:  DIRECT_COMMUNICATION_RELEASE
%     Type 7:  DIRECT_COMMUNICATION_RELEASE_ACCEPT
%     Type 10: DIRECT_RENEGOTIATION_REQUEST
%     Type 11: DIRECT_RENEGOTIATION_RESPONSE
%     Type 16: DIRECT_DISCOVERY_SOLICITATION
%     Type 17: DIRECT_DISCOVERY_RESPONSE
%
%   PC5-S message format (simplified binary, minimal subset):
%     Byte 0:     Message Type (uint8)
%     Bytes 1-3:  Sequence Number (uint24, per-link)
%     Bytes 4-7:  Source L2 ID (uint32, 24-bit actually, upper byte=0)
%     Bytes 8-11: Destination L2 ID (uint32)
%     Bytes 12+:  IEs (variable length)
%
%   Timers (TS 24.386 Section 8.5):
%     T5087: 1s  — retransmit DCR if no DCA/DCRej received
%     T5088: 10s — keepalive interval
%     T5089: 30s — link release timeout
%
%   PC5 Link QoS Parameters (TS 24.386 Section 5.3):
%     PC5 QoS Flow: {PQI, GFBR, MFBR, Notification_Control, MaxBurst}
%     PC5 QoS Profile: list of QoS flows
%
%   Usage:
%     pc5s = PC5SProtocol(ueID, sourceL2ID);
%     dcr  = pc5s.buildDCR(destL2ID, qosFlows);
%     pdu  = pc5s.buildKeepalive(destL2ID);
%     msg  = pc5s.processMessage(rxBytes, srcL2ID);
%
%   References:
%     3GPP TS 24.386 v17.4.0 — UE-to-UE PC5 signalling
%     3GPP TS 23.287 v17.0.0 — V2X QoS architecture

%   Copyright 2025. NR Sidelink Simulation Platform.

    % Message type constants (TS 24.386 Sec 9.3.1)
    properties (Constant)
        MSG_DCR     = uint8(1)    % DIRECT_COMMUNICATION_REQUEST
        MSG_DCA     = uint8(2)    % DIRECT_COMMUNICATION_ACCEPT
        MSG_DCREJ   = uint8(3)    % DIRECT_COMMUNICATION_REJECT
        MSG_KA      = uint8(4)    % DIRECT_COMMUNICATION_KEEPALIVE
        MSG_KA_ACK  = uint8(5)   % DIRECT_COMMUNICATION_KEEPALIVE_ACK
        MSG_REL     = uint8(6)    % DIRECT_COMMUNICATION_RELEASE
        MSG_REL_A   = uint8(7)   % DIRECT_COMMUNICATION_RELEASE_ACCEPT
        MSG_RENEG_Q = uint8(10)  % DIRECT_RENEGOTIATION_REQUEST
        MSG_RENEG_R = uint8(11)  % DIRECT_RENEGOTIATION_RESPONSE
        MSG_DISC_S  = uint8(16)  % DIRECT_DISCOVERY_SOLICITATION
        MSG_DISC_R  = uint8(17)  % DIRECT_DISCOVERY_RESPONSE

        % Reject causes (TS 24.386 Sec 9.3.3 / 9.7)
        REJ_UNSPECIFIED         = 0
        REJ_QOS_NOT_ACCEPTABLE  = 1
        REJ_NO_RESOURCE         = 2
        REJ_USER_BUSY           = 3
        REJ_SECURITY_FAILURE    = 4
        REJ_LINK_ALREADY_EXISTS = 5

        % Release causes
        REL_NORMAL             = 0
        REL_INACTIVITY         = 1
        REL_RESOURCE_RELEASE   = 2
        REL_USER_REQUEST       = 3

        % Timer values (in ms)
        T5087_MS = 1000    % DCR retransmit
        T5088_MS = 10000   % Keepalive interval
        T5089_MS = 30000   % Link release timeout
    end

    properties
        UEID        (1,1) uint32 = 1
        SourceL2ID  (1,1) uint32 = 0

        % PC5 QoS configuration
        DefaultQoSFlows = []  % Default QoS flows to request (cell of structs)
        KeepaliveEnabled (1,1) logical = true
    end

    properties (SetAccess = private)
        % Per-peer link context
        LinkContexts = struct()  % Indexed by 'id<l2id>'

        % Outbound message queue
        TxQueue = {}

        % Stats
        TxMsgCount  (1,1) uint32 = 0
        RxMsgCount  (1,1) uint32 = 0
    end

    methods
        function obj = PC5SProtocol(ueID, sourceL2ID)
        %PC5SProtocol Construct for a UE
            obj.UEID       = uint32(ueID);
            obj.SourceL2ID = uint32(sourceL2ID);
            obj.DefaultQoSFlows = obj.defaultV2XQoSFlows();
        end

        %% ----- Message builders -----

        function bytes = buildDCR(obj, destL2ID, qosFlows)
        %buildDCR Build a DIRECT_COMMUNICATION_REQUEST message
        %   destL2ID:  target UE L2 identifier (24-bit)
        %   qosFlows:  cell array of QoS flow structs (default: V2X defaults)
        %
        %   IE structure in message body (after 12-byte fixed header):
        %     IE Type(1) | IE Len(1) | IE Value(variable)
        %   IE Type 1: PC5 QoS Flows (simplified: PQI list)
        %   IE Type 2: IP address config request
        %   IE Type 3: PC5 Link Identifier
            if nargin < 3 || isempty(qosFlows)
                qosFlows = obj.DefaultQoSFlows;
            end
            seq    = obj.nextSeqNum(destL2ID);
            header = obj.buildHeader(obj.MSG_DCR, seq, destL2ID);
            ie_qos = obj.encodeQoSFlowsIE(qosFlows);
            ie_lid = obj.encodeLinkIdentifierIE(obj.SourceL2ID, uint32(destL2ID));
            bytes  = [header, ie_qos, ie_lid];
            obj.TxMsgCount = obj.TxMsgCount + 1;
        end

        function bytes = buildDCA(obj, destL2ID, acceptedFlows)
        %buildDCA Build a DIRECT_COMMUNICATION_ACCEPT message
            if nargin < 3; acceptedFlows = obj.DefaultQoSFlows; end
            seq   = obj.nextSeqNum(destL2ID);
            bytes = [obj.buildHeader(obj.MSG_DCA, seq, destL2ID), ...
                     obj.encodeQoSFlowsIE(acceptedFlows)];
            obj.TxMsgCount = obj.TxMsgCount + 1;
        end

        function bytes = buildDCRej(obj, destL2ID, cause)
        %buildDCRej Build a DIRECT_COMMUNICATION_REJECT message
            if nargin < 3; cause = obj.REJ_UNSPECIFIED; end
            seq   = obj.nextSeqNum(destL2ID);
            bytes = [obj.buildHeader(obj.MSG_DCREJ, seq, destL2ID), uint8(cause)];
            obj.TxMsgCount = obj.TxMsgCount + 1;
        end

        function bytes = buildKeepalive(obj, destL2ID)
        %buildKeepalive Build a DIRECT_COMMUNICATION_KEEPALIVE message
            seq   = obj.nextSeqNum(destL2ID);
            bytes = obj.buildHeader(obj.MSG_KA, seq, destL2ID);
            obj.TxMsgCount = obj.TxMsgCount + 1;
        end

        function bytes = buildKeepaliveAck(obj, destL2ID)
        %buildKeepaliveAck Build a DIRECT_COMMUNICATION_KEEPALIVE_ACK message
            seq   = obj.nextSeqNum(destL2ID);
            bytes = obj.buildHeader(obj.MSG_KA_ACK, seq, destL2ID);
            obj.TxMsgCount = obj.TxMsgCount + 1;
        end

        function bytes = buildRelease(obj, destL2ID, cause)
        %buildRelease Build a DIRECT_COMMUNICATION_RELEASE message
            if nargin < 3; cause = obj.REL_USER_REQUEST; end
            seq   = obj.nextSeqNum(destL2ID);
            bytes = [obj.buildHeader(obj.MSG_REL, seq, destL2ID), uint8(cause)];
            obj.TxMsgCount = obj.TxMsgCount + 1;
        end

        function bytes = buildReleaseAccept(obj, destL2ID)
        %buildReleaseAccept Build a DIRECT_COMMUNICATION_RELEASE_ACCEPT message
            seq   = obj.nextSeqNum(destL2ID);
            bytes = obj.buildHeader(obj.MSG_REL_A, seq, destL2ID);
            obj.TxMsgCount = obj.TxMsgCount + 1;
        end

        function bytes = buildRenegRequest(obj, destL2ID, newFlows)
        %buildRenegRequest Build a DIRECT_RENEGOTIATION_REQUEST message
            seq   = obj.nextSeqNum(destL2ID);
            bytes = [obj.buildHeader(obj.MSG_RENEG_Q, seq, destL2ID), ...
                     obj.encodeQoSFlowsIE(newFlows)];
            obj.TxMsgCount = obj.TxMsgCount + 1;
        end

        %% ----- Message processing -----

        function [resp, info] = processMessage(obj, msgBytes, srcL2ID)
        %processMessage Process a received PC5-S message
        %   Returns response message (bytes) and info struct.
        %   info.type, info.seqNum, info.srcL2ID, info.cause, info.qosFlows
            resp = [];
            info = struct('type', 0, 'seqNum', 0, 'srcL2ID', srcL2ID, ...
                          'cause', 0, 'qosFlows', {{}});

            if isempty(msgBytes) || numel(msgBytes) < 12; return; end
            msgBytes = uint8(msgBytes(:)');
            obj.RxMsgCount = obj.RxMsgCount + 1;

            msgType = msgBytes(1);
            seqNum  = double(msgBytes(2))*65536 + double(msgBytes(3))*256 + double(msgBytes(4));
            % srcL2ID from bytes 5-8 (but caller passes it separately)
            info.type   = msgType;
            info.seqNum = seqNum;

            switch msgType
                case obj.MSG_DCR
                    % Accept: build DCA
                    qosFlows = obj.decodeQoSFlowsIE(msgBytes(13:end));
                    info.qosFlows = qosFlows;
                    resp = obj.buildDCA(srcL2ID);
                    obj.updateLinkContext(srcL2ID, 'established');

                case obj.MSG_DCA
                    info.qosFlows = obj.decodeQoSFlowsIE(msgBytes(13:end));
                    obj.updateLinkContext(srcL2ID, 'established');

                case obj.MSG_DCREJ
                    if numel(msgBytes) >= 13; info.cause = msgBytes(13); end
                    obj.updateLinkContext(srcL2ID, 'idle');

                case obj.MSG_KA
                    resp = obj.buildKeepaliveAck(srcL2ID);
                    obj.updateLinkContext(srcL2ID, 'keepalive_rx');

                case obj.MSG_KA_ACK
                    obj.updateLinkContext(srcL2ID, 'keepalive_ack');

                case obj.MSG_REL
                    if numel(msgBytes) >= 13; info.cause = msgBytes(13); end
                    resp = obj.buildReleaseAccept(srcL2ID);
                    obj.updateLinkContext(srcL2ID, 'idle');

                case obj.MSG_REL_A
                    obj.updateLinkContext(srcL2ID, 'idle');

                case obj.MSG_RENEG_Q
                    % Accept renegotiation with same flows
                    newFlows = obj.decodeQoSFlowsIE(msgBytes(13:end));
                    info.qosFlows = newFlows;
                    % Simplified: always accept
                    respHdr = obj.buildHeader(obj.MSG_RENEG_R, ...
                                  obj.nextSeqNum(srcL2ID), srcL2ID);
                    resp = [respHdr, uint8(0)];  % cause=0 (accepted)
                    obj.TxMsgCount = obj.TxMsgCount + 1;
            end
        end

        %% ----- Link queries -----

        function ctx = getLinkContext(obj, destL2ID)
        %getLinkContext Get link context struct for a peer
            key = sprintf('id%u', uint32(destL2ID));
            if isfield(obj.LinkContexts, key)
                ctx = obj.LinkContexts.(key);
            else
                ctx = struct('state', 'idle', 'seqNum', 0, 'qosFlows', {{}});
            end
        end

        function stats = getStats(obj)
        %getStats Return statistics struct
            stats = struct('TxMsgs', obj.TxMsgCount, 'RxMsgs', obj.RxMsgCount);
        end

        function reset(obj)
            obj.LinkContexts = struct();
            obj.TxQueue = {};
            obj.TxMsgCount = 0;
            obj.RxMsgCount = 0;
        end
    end

    %% ----- Private -----
    methods (Access = private)

        function hdr = buildHeader(obj, msgType, seqNum, destL2ID)
            % [MsgType(1)][SeqNum(3)][SrcL2ID(4)][DstL2ID(4)] = 12 bytes
            sn = uint32(seqNum);
            hdr = [msgType, ...
                   uint8(bitshift(sn,-16)&255), uint8(bitshift(sn,-8)&255), uint8(sn&255), ...
                   obj.u32ToBytes(obj.SourceL2ID), ...
                   obj.u32ToBytes(uint32(destL2ID))];
        end

        function sn = nextSeqNum(obj, destL2ID)
            key = sprintf('id%u', uint32(destL2ID));
            if ~isfield(obj.LinkContexts, key)
                obj.LinkContexts.(key) = struct('state','idle','seqNum',0,'qosFlows',{{}});
            end
            sn = obj.LinkContexts.(key).seqNum;
            obj.LinkContexts.(key).seqNum = mod(sn + 1, 2^24);
        end

        function updateLinkContext(obj, destL2ID, state)
            key = sprintf('id%u', uint32(destL2ID));
            if ~isfield(obj.LinkContexts, key)
                obj.LinkContexts.(key) = struct('state','idle','seqNum',0,'qosFlows',{{}});
            end
            obj.LinkContexts.(key).state = state;
        end

        function bytes = encodeQoSFlowsIE(~, flows)
            % IE Type=1, IE Len=N*3, each flow = [PQI(1), GFBRkbps_hi(1), GFBRkbps_lo(1)]
            if isempty(flows)
                bytes = uint8([1, 0]);  % IE type=1, length=0
                return;
            end
            ieData = uint8([]);
            for i = 1:numel(flows)
                f = flows{i};
                pqi  = uint8(getF(f,'PQI',55));
                gfbr = uint16(getF(f,'GFBR_kbps',0));
                ieData = [ieData, pqi, uint8(bitshift(gfbr,-8)), uint8(gfbr&255)]; %#ok<AGROW>
            end
            bytes = [uint8(1), uint8(numel(ieData)), ieData];
        end

        function flows = decodeQoSFlowsIE(~, bytes)
            flows = {};
            if numel(bytes) < 2; return; end
            if bytes(1) ~= 1; return; end  % not QoS IE
            ieLen = bytes(2);
            if numel(bytes) < 2 + ieLen; return; end
            for i = 1:3:ieLen
                if i+2 <= ieLen
                    pqi  = double(bytes(2+i));
                    gfbr = double(bytes(3+i))*256 + double(bytes(4+i));
                    flows{end+1} = struct('PQI', pqi, 'GFBR_kbps', gfbr); %#ok<AGROW>
                end
            end
        end

        function bytes = encodeLinkIdentifierIE(~, srcL2ID, dstL2ID)
            % IE Type=2, IE Len=8, SrcL2ID(4)+DstL2ID(4)
            b = [uint8(2), uint8(8), ...
                 uint8(bitshift(uint32(srcL2ID),-24)&255), ...
                 uint8(bitshift(uint32(srcL2ID),-16)&255), ...
                 uint8(bitshift(uint32(srcL2ID),-8)&255), ...
                 uint8(uint32(srcL2ID)&255), ...
                 uint8(bitshift(uint32(dstL2ID),-24)&255), ...
                 uint8(bitshift(uint32(dstL2ID),-16)&255), ...
                 uint8(bitshift(uint32(dstL2ID),-8)&255), ...
                 uint8(uint32(dstL2ID)&255)];
            bytes = b;
        end

        function b = u32ToBytes(~, v)
            b = uint8([bitshift(uint32(v),-24)&255, bitshift(uint32(v),-16)&255, ...
                       bitshift(uint32(v),-8)&255, uint32(v)&255]);
        end

        function flows = defaultV2XQoSFlows(~)
            % Standard NR V2X QoS flows (TS 23.287 Table 5.3.1-1)
            flows = { ...
                struct('PQI', 55, 'GFBR_kbps', 0,    'MFBR_kbps', 0, ...
                       'Type', 'Non-GBR', 'PDB_ms', 100, 'PER', 0.01), ...  % CAM
                struct('PQI', 65, 'GFBR_kbps', 2000, 'MFBR_kbps', 4000, ...
                       'Type', 'GBR', 'PDB_ms', 100, 'PER', 0.001), ...     % sensor sharing
                struct('PQI', 91, 'GFBR_kbps', 1000, 'MFBR_kbps', 2000, ...
                       'Type', 'DC-GBR', 'PDB_ms', 3, 'PER', 0.0001) ...    % URLLC
            };
        end
    end
end

function v = getF(s, field, default)
    if isfield(s, field); v = s.(field); else; v = default; end
end
