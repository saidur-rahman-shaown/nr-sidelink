classdef SidelinkRLCEntity < handle
%SidelinkRLCEntity NR Sidelink RLC entity — UM and TM modes (TS 38.322)
%
%   Simplified functional model implementing the RLC sublayer for NR
%   sidelink PC5 bearers used in broadcast and groupcast transmissions.
%
%   Supports:
%     UM (Unacknowledged Mode) — segmentation, SN assignment, reassembly
%     TM (Transparent Mode)   — pass-through, no header, no SN
%
%   UM PDU header format (12-bit SN per TS 38.322 Sec 6.2.2.3):
%     Byte 0: [R:2][SI:2][SN_hi:4]   (high nibble of SN, R=reserved)
%     Byte 1: [SN_lo:8]              (low byte of SN)
%     Byte 2-3: [SO:16]              (segment offset, present when SI != 00)
%
%   SI field values:
%     00 = complete SDU (no SO field)
%     01 = first segment
%     10 = last segment
%     11 = middle segment
%
%   For unicast bearers requiring ARQ, use SidelinkRLCEntityAM.
%
%   Usage:
%     rlc = SidelinkRLCEntity('Mode', 'UM', 'LCID', 3, 'SNBits', 12);
%     rlc.submitSDU(sduBytes);          % from PDCP
%     pdus = rlc.assemblePDUs(maxBytes);% to MAC
%     rlc.receiveRxPDU(rxPDU);         % from MAC
%     sdus = rlc.getReassembledSDUs(); % to PDCP
%
%   References:
%     3GPP TS 38.322 v17.0.0 — NR; Radio Link Control (RLC) protocol spec
%     PC5 sidelink bearer types: SL-SRB0 (TM), SL-SRB3 (UM), DRB1-7 (UM/AM)

%   Copyright 2025. NR Sidelink Simulation Platform.

    properties
        Mode         (1,:) char = 'UM'    % 'UM' or 'TM'
        LCID         (1,1) uint8 = 3      % Logical channel ID
        SNBits       (1,1) double {mustBeMember(SNBits,[6,12])} = 12
        MaxPDUBytes  (1,1) double = 300   % Max RLC PDU payload in bytes
    end

    properties (SetAccess = protected)
        TxNextSN     (1,1) uint32 = 0  % Next SN to assign on TX side
        RxDelivered  = {}              % Fully reassembled SDUs queued for PDCP

        TxSDUQueue   = {}              % Cell array: pending SDU byte vectors (uint8)
        RxSegStore   = struct()        % Fragment store: field sn_XXXXX = {segs}

        % Statistics
        TxPDUCount   (1,1) uint32 = 0
        RxPDUCount   (1,1) uint32 = 0
        DropCount    (1,1) uint32 = 0
    end

    properties (Dependent)
        SNModulus     % 2^SNBits
        HeaderBytes   % Header size in bytes (excl. SO field)
    end

    methods
        function obj = SidelinkRLCEntity(varargin)
        %SidelinkRLCEntity Construct with name-value pairs
            for i = 1:2:numel(varargin)
                obj.(varargin{i}) = varargin{i+1};
            end
        end

        function m = get.SNModulus(obj)
            m = 2^obj.SNBits;
        end

        function h = get.HeaderBytes(obj)
            if obj.SNBits == 6
                h = 1;  % 1 byte: R(2)|SI(2)|SN(4) ... SN[5:4] in next? We use 2 bytes for clarity
                h = 2;  % Use 2 bytes for both SN widths to keep uniform parsing
            else
                h = 2;
            end
        end

        %% ----- TX API -----

        function submitSDU(obj, sdu)
        %submitSDU Accept an SDU from PDCP and buffer it
        %   sdu: uint8 byte vector
            if isempty(sdu); return; end
            obj.TxSDUQueue{end+1} = uint8(sdu(:)');
        end

        function pdus = assemblePDUs(obj, maxPDUBytes)
        %assemblePDUs Build RLC PDUs from buffered SDUs
        %   maxPDUBytes: maximum total bytes per PDU (header + payload)
        %   Returns cell array of uint8 byte vectors.
            if nargin < 2 || isempty(maxPDUBytes)
                maxPDUBytes = obj.MaxPDUBytes;
            end
            pdus = {};

            if isempty(obj.TxSDUQueue)
                return;
            end

            if strcmpi(obj.Mode, 'TM')
                % TM: one PDU per SDU, no header added
                while ~isempty(obj.TxSDUQueue)
                    pdus{end+1} = obj.TxSDUQueue{1}; %#ok<AGROW>
                    obj.TxSDUQueue(1) = [];
                    obj.TxPDUCount = obj.TxPDUCount + 1;
                end
                return;
            end

            % UM mode: process queued SDUs with segmentation
            while ~isempty(obj.TxSDUQueue)
                sdu     = obj.TxSDUQueue{1};
                obj.TxSDUQueue(1) = [];
                sduLen  = numel(sdu);
                soHdr   = 2;  % Segment offset field size
                maxPay  = maxPDUBytes - obj.HeaderBytes;  % Payload bytes per PDU

                if sduLen <= maxPay
                    % Complete SDU fits — no segmentation needed
                    hdr  = obj.buildHeader(obj.TxNextSN, 0, 0);  % SI=00 (complete)
                    pdus{end+1} = [hdr, sdu]; %#ok<AGROW>
                    obj.TxNextSN = uint32(mod(obj.TxNextSN + 1, obj.SNModulus));
                    obj.TxPDUCount = obj.TxPDUCount + 1;
                else
                    % Segment SDU across multiple PDUs (same SN)
                    sn      = obj.TxNextSN;
                    offset  = 0;
                    isFirst = true;
                    maxSegPay = maxPDUBytes - obj.HeaderBytes - soHdr;  % Leave room for SO

                    while offset < sduLen
                        remaining = sduLen - offset;
                        if isFirst
                            siCode = 1;  % first
                        elseif remaining <= maxSegPay
                            siCode = 2;  % last
                        else
                            siCode = 3;  % middle
                        end

                        if isFirst
                            % First segment: no SO field needed per spec (SO=0 implied)
                            segLen = min(maxPay, remaining);
                            so = 0;
                            hdr = obj.buildHeader(sn, siCode, so);
                        else
                            segLen = min(maxSegPay, remaining);
                            so = offset;
                            hdr = obj.buildHeader(sn, siCode, so);
                        end

                        seg = sdu(offset+1 : offset+segLen);
                        pdus{end+1} = [hdr, seg]; %#ok<AGROW>
                        obj.TxPDUCount = obj.TxPDUCount + 1;
                        offset  = offset + segLen;
                        isFirst = false;
                    end
                    obj.TxNextSN = uint32(mod(sn + 1, obj.SNModulus));
                end
            end
        end

        %% ----- RX API -----

        function receiveRxPDU(obj, pdu)
        %receiveRxPDU Process a received RLC PDU from MAC
        %   pdu: uint8 byte vector
            if isempty(pdu); return; end
            obj.RxPDUCount = obj.RxPDUCount + 1;

            if strcmpi(obj.Mode, 'TM')
                obj.RxDelivered{end+1} = uint8(pdu(:)');
                return;
            end

            % UM: parse header and reassemble
            [sn, siCode, so, payload] = obj.parseHeader(pdu);
            if isempty(payload); obj.DropCount = obj.DropCount + 1; return; end

            if siCode == 0
                % Complete SDU
                obj.RxDelivered{end+1} = payload;
                return;
            end

            % Segmented: store fragment
            key = sprintf('sn%u', sn);
            seg = struct('so', so, 'data', payload, 'isLast', (siCode == 2));

            if ~isfield(obj.RxSegStore, key)
                obj.RxSegStore.(key) = {};
            end
            obj.RxSegStore.(key){end+1} = seg;

            % Try to reassemble if last segment arrived
            if siCode == 2
                sdu = obj.tryReassemble(key);
                if ~isempty(sdu)
                    obj.RxDelivered{end+1} = sdu;
                    obj.RxSegStore = rmfield(obj.RxSegStore, key);
                end
            end
        end

        function sdus = getReassembledSDUs(obj)
        %getReassembledSDUs Return all fully reassembled SDUs and clear buffer
            sdus = obj.RxDelivered;
            obj.RxDelivered = {};
        end

        %% ----- Utilities -----

        function stats = getStats(obj)
        %getStats Return statistics struct
            stats = struct( ...
                'Mode',       obj.Mode, ...
                'LCID',       obj.LCID, ...
                'TxPDUs',     obj.TxPDUCount, ...
                'RxPDUs',     obj.RxPDUCount, ...
                'Dropped',    obj.DropCount, ...
                'TxNextSN',   obj.TxNextSN);
        end

        function reset(obj)
        %reset Clear all TX/RX state
            obj.TxNextSN     = 0;
            obj.TxSDUQueue   = {};
            obj.RxSegStore   = struct();
            obj.RxDelivered  = {};
            obj.TxPDUCount   = 0;
            obj.RxPDUCount   = 0;
            obj.DropCount    = 0;
        end
    end

    %% ----- Private helpers -----
    methods (Access = protected)

        function hdr = buildHeader(obj, sn, siCode, so)
        %buildHeader Build UM RLC PDU header bytes
        %   sn:     sequence number (uint32)
        %   siCode: 0=complete, 1=first, 2=last, 3=middle
        %   so:     segment offset (bytes), 0 for first/complete
            if obj.SNBits == 12
                % 2-byte base header: [R(2)|SI(2)|SN_hi(4)] [SN_lo(8)]
                b0 = uint8(bitor(bitshift(uint16(siCode), 4), ...
                                 uint16(bitshift(sn, -8) & 15)));
                b1 = uint8(sn & 255);
                hdr = [b0, b1];
            else
                % 6-bit SN: 2-byte header for uniform parsing
                b0 = uint8(bitor(bitshift(uint8(siCode), 6), ...
                                 uint8(bitshift(sn, -2) & 63)));  %#ok — conceptual
                % Store full SN across 2 bytes: [R(1)|R(1)|SI(2)|SN_hi(4)] [SN_lo(2)|...]
                b0 = uint8(bitor(uint8(bitshift(siCode, 4)), uint8(bitshift(sn,-2) & 15)));
                b1 = uint8(bitshift(bitand(uint16(sn), 3), 6));  % SN[1:0] in top 2 bits
                hdr = [b0, b1];
            end

            % Append SO for non-first segmented PDUs
            if siCode >= 2 || (siCode == 3)
                hdr = [hdr, uint8(bitshift(so,-8) & 255), uint8(so & 255)];
            elseif siCode == 3
                hdr = [hdr, uint8(bitshift(so,-8) & 255), uint8(so & 255)];
            end
            % First segment (siCode==1) has SO=0 (implied by spec), no SO field
            if siCode == 2 || siCode == 3
                % SO already appended above
            end
        end

        function [sn, siCode, so, payload] = parseHeader(obj, pdu)
        %parseHeader Parse UM RLC PDU header
        %   Returns sn, siCode (0..3), so (segment offset), payload bytes
            pdu = uint8(pdu(:)');
            if numel(pdu) < 2
                sn = 0; siCode = 0; so = 0; payload = [];
                return;
            end

            if obj.SNBits == 12
                siCode  = double(bitshift(bitand(pdu(1), uint8(48)), -4));  % bits [5:4]
                sn_hi   = double(bitand(pdu(1), uint8(15)));                % bits [3:0]
                sn_lo   = double(pdu(2));
                sn      = sn_hi * 256 + sn_lo;
                payStart = 3;
            else
                siCode  = double(bitshift(bitand(pdu(1), uint8(48)), -4));
                sn_hi4  = double(bitand(pdu(1), uint8(15)));
                sn_lo2  = double(bitshift(bitand(pdu(2), uint8(192)), -6));
                sn      = sn_hi4 * 4 + sn_lo2;
                payStart = 3;
            end

            so = 0;
            if siCode >= 2 && numel(pdu) >= payStart + 1
                so = double(pdu(payStart)) * 256 + double(pdu(payStart+1));
                payStart = payStart + 2;
            end

            if payStart <= numel(pdu)
                payload = pdu(payStart:end);
            else
                payload = uint8([]);
            end
        end

        function sdu = tryReassemble(obj, key)
        %tryReassemble Attempt SDU reassembly from stored segments
            segs = obj.RxSegStore.(key);
            % Check that we have a last segment
            hasLast = any(cellfun(@(s) s.isLast, segs));
            if ~hasLast
                sdu = [];
                return;
            end
            % Sort by segment offset and concatenate
            sos  = cellfun(@(s) s.so, segs);
            [~, idx] = sort(sos);
            sdu = uint8([]);
            for k = idx
                sdu = [sdu, segs{k}.data]; %#ok<AGROW>
            end
        end
    end
end
