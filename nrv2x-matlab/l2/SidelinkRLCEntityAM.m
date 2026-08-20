classdef SidelinkRLCEntityAM < SidelinkRLCEntity
%SidelinkRLCEntityAM NR Sidelink RLC AM entity for unicast PC5 bearers
%
%   Extends SidelinkRLCEntity with Acknowledged Mode (AM) operation:
%     - Poll bit and retransmission triggering
%     - STATUS PDU generation (ACK/NACK feedback)
%     - Retransmission buffer for NACKed PDUs
%     - TX/RX window management
%
%   AM PDU header (12-bit SN, TS 38.322 Sec 6.2.2.4):
%     Byte 0: [D/C(1)=1][P(1)][SI(2)][SN_hi(4)]
%     Byte 1: [SN_lo(8)]
%     Byte 2-3: [SO(16)]  (present when SI != 00)
%
%   AM STATUS PDU (TS 38.322 Sec 6.2.2.5):
%     Byte 0: [D/C(1)=0][CPT(3)=000][ACK_SN_hi(4)]
%     Byte 1: [ACK_SN_lo(8)]
%     Byte 2: [E1(1)][...] (E1=1 → NACK_SN fields follow)
%
%   TX window: [TX_Next_Ack .. TX_Next_Ack + WindowSize)
%   RX window: [RX_Next      .. RX_Next + WindowSize)
%
%   References:
%     3GPP TS 38.322 v17.0.0 Sections 5.2, 5.3, 6.2

%   Copyright 2025. NR Sidelink Simulation Platform.

    properties
        WindowSize   (1,1) double = 2048    % AM TX/RX window (2^11 for 12-bit SN)
        PollPDU      (1,1) double = 64      % Poll trigger: every N PDUs (-1 = disable)
        PollByte     (1,1) double = 125000  % Poll trigger: every N bytes (-1 = disable)
        MaxRetx      (1,1) double = 4       % Max retransmissions before giving up
    end

    properties (SetAccess = private)
        % TX side
        TxNextAck    (1,1) uint32 = 0   % Oldest unACKed SN
        TxPollSN     (1,1) int64  = -1  % SN of last polled PDU (-1 if none pending)
        TxPDUsSinceAck (1,1) uint32 = 0 % PDU counter for poll triggering
        RetxQueue    = {}               % Cell of {pdu, sn, retxCount} structs
        TxPDUStore   = {}               % Stored AMD PDUs indexed by SN (for retx)

        % RX side
        RxNextExp    (1,1) uint32 = 0   % Next expected SN (for in-order delivery)
        RxOOOBuffer  = struct()         % Out-of-order RX AMD PDUs: field sn_XXX
        NACKList     = []               % SNs to NACK in next STATUS PDU
        PendingACK   (1,1) uint32 = 0   % ACK_SN for next STATUS PDU
        StatusNeeded (1,1) logical = false  % Trigger for STATUS PDU transmission
    end

    methods
        function obj = SidelinkRLCEntityAM(varargin)
        %SidelinkRLCEntityAM Construct with name-value pairs
            obj = obj@SidelinkRLCEntity(varargin{:});
            obj.Mode = 'AM';
        end

        %% ----- TX overrides -----

        function pdus = assemblePDUs(obj, maxPDUBytes)
        %assemblePDUs Build AMD PDUs from buffer, poll when required
        %   Returns cell array of uint8 byte vectors.
            if nargin < 2 || isempty(maxPDUBytes)
                maxPDUBytes = obj.MaxPDUBytes;
            end
            pdus = {};

            % First: inject retransmissions if any
            while ~isempty(obj.RetxQueue)
                rt = obj.RetxQueue{1};
                obj.RetxQueue(1) = [];
                if rt.retxCount >= obj.MaxRetx
                    % Give up on this PDU
                    obj.DropCount = obj.DropCount + 1;
                    continue;
                end
                % Re-build PDU with new poll bit
                needPoll = obj.shouldPoll();
                pdu = obj.repackAMDPDU(rt.pdu, needPoll);
                pdus{end+1} = pdu; %#ok<AGROW>
                obj.TxPDUCount = obj.TxPDUCount + 1;
                return;
            end

            % Then: new SDUs from queue
            while ~isempty(obj.TxSDUQueue)
                sdu    = obj.TxSDUQueue{1};
                obj.TxSDUQueue(1) = [];
                sduLen = numel(sdu);
                soHdr  = 2;
                maxPay = maxPDUBytes - 2;  % AM base header = 2 bytes

                needPoll = obj.shouldPoll();

                if sduLen <= maxPay
                    hdr  = obj.buildAMHeader(obj.TxNextSN, 0, 0, needPoll);
                    pdu  = [hdr, sdu];
                    obj.storeTxPDU(obj.TxNextSN, pdu);
                    pdus{end+1} = pdu; %#ok<AGROW>
                    obj.TxNextSN = uint32(mod(obj.TxNextSN + 1, obj.SNModulus));
                    obj.TxPDUCount   = obj.TxPDUCount + 1;
                    obj.TxPDUsSinceAck = obj.TxPDUsSinceAck + 1;
                else
                    sn      = obj.TxNextSN;
                    offset  = 0;
                    isFirst = true;
                    maxSegPay = maxPDUBytes - 2 - soHdr;

                    while offset < sduLen
                        remaining = sduLen - offset;
                        if isFirst
                            siCode = 1;
                        elseif remaining <= maxSegPay
                            siCode = 2;
                        else
                            siCode = 3;
                        end
                        segLen = ternaryNum(isFirst, min(maxPay, remaining), min(maxSegPay, remaining));
                        seg    = sdu(offset+1 : offset+segLen);
                        so     = offset;
                        if isFirst; so = 0; end
                        np  = needPoll && (siCode == 2 || (isFirst && sduLen <= maxPay));
                        hdr = obj.buildAMHeader(sn, siCode, so, np);
                        pdu = [hdr, seg];
                        obj.storeTxPDU(sn, pdu);
                        pdus{end+1} = pdu; %#ok<AGROW>
                        obj.TxPDUCount   = obj.TxPDUCount + 1;
                        obj.TxPDUsSinceAck = obj.TxPDUsSinceAck + 1;
                        offset  = offset + segLen;
                        isFirst = false;
                    end
                    obj.TxNextSN = uint32(mod(sn + 1, obj.SNModulus));
                end
            end
        end

        %% ----- RX & ARQ -----

        function receiveRxPDU(obj, pdu)
        %receiveRxPDU Process a received AMD or STATUS PDU
            if isempty(pdu); return; end
            obj.RxPDUCount = obj.RxPDUCount + 1;
            pdu = uint8(pdu(:)');

            dcBit = bitshift(bitand(pdu(1), uint8(128)), -7);
            if dcBit == 0
                % STATUS PDU
                obj.processStatusPDU(pdu);
                return;
            end

            % AMD data PDU
            [sn, siCode, so, payload, ~] = obj.parseAMHeader(pdu);
            if isempty(payload); obj.DropCount = obj.DropCount + 1; return; end

            % Request STATUS if poll bit was set
            pBit = bitshift(bitand(pdu(1), uint8(64)), -6);
            if pBit
                obj.StatusNeeded = true;
                obj.PendingACK = uint32(mod(sn + 1, obj.SNModulus));
            end

            if siCode == 0
                % Complete SDU
                if sn == obj.RxNextExp
                    obj.RxDelivered{end+1} = payload;
                    obj.RxNextExp = uint32(mod(obj.RxNextExp + 1, obj.SNModulus));
                    obj.drainOOOBuffer();
                else
                    obj.bufferOOO(sn, siCode, so, payload);
                    obj.NACKList(end+1) = obj.RxNextExp;
                end
                return;
            end

            % Segmented AMD PDU — buffer for reassembly
            obj.bufferOOO(sn, siCode, so, payload);
            if siCode == 2  % last segment
                key = sprintf('sn%u', sn);
                reassembled = obj.tryReassemble(key);
                if ~isempty(reassembled)
                    if sn == obj.RxNextExp
                        obj.RxDelivered{end+1} = reassembled;
                        obj.RxNextExp = uint32(mod(obj.RxNextExp + 1, obj.SNModulus));
                        if isfield(obj.RxOOOBuffer, key)
                            obj.RxOOOBuffer = rmfield(obj.RxOOOBuffer, key);
                        end
                        obj.drainOOOBuffer();
                    end
                end
            end
        end

        function statusPDU = buildStatusPDU(obj)
        %buildStatusPDU Generate an AM STATUS PDU for peer feedback
        %   Returns uint8 byte vector (or [] if no status needed).
            if ~obj.StatusNeeded && isempty(obj.NACKList)
                statusPDU = [];
                return;
            end
            ackSN = obj.PendingACK;
            % Simple STATUS: ACK_SN with no NACK entries (simplified)
            % Full ARQ would include NACK_SN fields (E1=1 chain)
            b0 = uint8(bitshift(ackSN, -8) & 15);  % D/C=0, CPT=000, ACK_SN_hi
            b1 = uint8(ackSN & 255);
            b2 = uint8(0);  % E1=0 (no NACKs in simplified model)
            statusPDU = [b0, b1, b2];
            obj.StatusNeeded = false;
            obj.NACKList = [];
        end

        function reset(obj)
        %reset Clear all TX/RX state
            reset@SidelinkRLCEntity(obj);
            obj.TxNextAck    = 0;
            obj.TxPollSN     = -1;
            obj.TxPDUsSinceAck = 0;
            obj.RetxQueue    = {};
            obj.TxPDUStore   = {};
            obj.RxNextExp    = 0;
            obj.RxOOOBuffer  = struct();
            obj.NACKList     = [];
            obj.PendingACK   = 0;
            obj.StatusNeeded = false;
        end
    end

    methods (Access = private)

        function hdr = buildAMHeader(obj, sn, siCode, so, pollBit)
            % D/C=1 (bit7), P=pollBit (bit6), SI(2), SN_hi(4) in byte0; SN_lo in byte1
            pBit = uint8(pollBit) * uint8(64);
            b0   = bitor(uint8(128), bitor(pBit, ...
                   bitor(uint8(bitshift(siCode, 4)), uint8(bitshift(sn,-8) & 15))));
            b1   = uint8(sn & 255);
            hdr  = [b0, b1];
            if siCode ~= 0 && so > 0
                hdr = [hdr, uint8(bitshift(so,-8) & 255), uint8(so & 255)];
            end
        end

        function [sn, siCode, so, payload, pBit] = parseAMHeader(~, pdu)
            siCode  = double(bitshift(bitand(pdu(1), uint8(48)), -4));
            pBit    = double(bitshift(bitand(pdu(1), uint8(64)), -6));
            sn_hi   = double(bitand(pdu(1), uint8(15)));
            sn_lo   = double(pdu(2));
            sn      = sn_hi * 256 + sn_lo;
            payStart = 3;
            so = 0;
            if siCode ~= 0 && numel(pdu) >= 5
                so = double(pdu(3)) * 256 + double(pdu(4));
                payStart = 5;
            end
            if payStart <= numel(pdu)
                payload = pdu(payStart:end);
            else
                payload = uint8([]);
            end
        end

        function processStatusPDU(obj, pdu)
            % Parse ACK_SN from STATUS PDU and release TX buffer up to ACK_SN
            if numel(pdu) < 2; return; end
            ackSN = double(bitand(pdu(1), uint8(15))) * 256 + double(pdu(2));
            obj.TxNextAck    = uint32(ackSN);
            obj.TxPDUsSinceAck = 0;
            % Free stored PDUs up to ackSN
            sn = obj.TxNextAck;
            while sn ~= uint32(ackSN)
                key = sprintf('sn%u', sn);
                if isfield(obj.TxPDUStore, key)
                    obj.TxPDUStore = rmfield(obj.TxPDUStore, key);
                end
                sn = uint32(mod(sn + 1, obj.SNModulus));
            end
        end

        function storeTxPDU(obj, sn, pdu)
            key = sprintf('sn%u', sn);
            obj.TxPDUStore.(key) = pdu;
        end

        function needPoll = shouldPoll(obj)
            needPoll = false;
            if obj.PollPDU > 0 && mod(obj.TxPDUsSinceAck + 1, obj.PollPDU) == 0
                needPoll = true;
            end
        end

        function pdu = repackAMDPDU(obj, oldPDU, pollBit)
            % Rebuild the AMD PDU with updated poll bit
            p = uint8(oldPDU(:)');
            if pollBit
                p(1) = bitor(p(1), uint8(64));
            else
                p(1) = bitand(p(1), uint8(191));
            end
            pdu = p;
            [~, ~, ~, ~, obj.TxPollSN] = obj.parseAMHeader(p); %#ok (update poll SN)
        end

        function bufferOOO(obj, sn, siCode, so, payload)
            key = sprintf('sn%u', sn);
            if ~isfield(obj.RxOOOBuffer, key)
                obj.RxOOOBuffer.(key) = {};
            end
            seg = struct('so', so, 'data', payload, 'isLast', (siCode == 2));
            if siCode == 0
                seg.isLast = true;
            end
            obj.RxOOOBuffer.(key){end+1} = seg;
            % Mirror to base class RxSegStore for tryReassemble
            obj.RxSegStore.(key) = obj.RxOOOBuffer.(key);
        end

        function drainOOOBuffer(obj)
            % Deliver any now-in-order buffered SDUs
            cont = true;
            while cont
                key = sprintf('sn%u', obj.RxNextExp);
                cont = false;
                if isfield(obj.RxOOOBuffer, key)
                    segs = obj.RxOOOBuffer.(key);
                    if numel(segs) == 1 && segs{1}.so == 0 && segs{1}.isLast
                        obj.RxDelivered{end+1} = segs{1}.data;
                        obj.RxOOOBuffer = rmfield(obj.RxOOOBuffer, key);
                        obj.RxNextExp = uint32(mod(obj.RxNextExp + 1, obj.SNModulus));
                        cont = true;
                    else
                        sdu = obj.tryReassemble(key);
                        if ~isempty(sdu)
                            obj.RxDelivered{end+1} = sdu;
                            obj.RxOOOBuffer = rmfield(obj.RxOOOBuffer, key);
                            obj.RxSegStore  = rmfield(obj.RxSegStore, key);
                            obj.RxNextExp = uint32(mod(obj.RxNextExp + 1, obj.SNModulus));
                            cont = true;
                        end
                    end
                end
            end
        end
    end
end

function y = ternaryNum(cond, a, b)
%ternaryNum Inline conditional for numeric scalars
    if cond; y = a; else; y = b; end
end
