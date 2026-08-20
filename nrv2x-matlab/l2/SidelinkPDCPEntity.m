classdef SidelinkPDCPEntity < handle
%SidelinkPDCPEntity NR Sidelink PDCP entity (TS 38.323)
%
%   Simplified functional model of the Packet Data Convergence Protocol
%   for NR sidelink PC5 bearers, per 3GPP TS 38.323 v17.0.0.
%
%   Functions implemented:
%     - PDCP SDU/PDU header construction and parsing
%     - Sequence numbering (12-bit SN, the standard for SL DRBs)
%     - In-order delivery with reordering buffer
%     - Duplicate detection via SN comparison
%     - Integrity protection and ciphering hooks (stub — no actual crypto)
%     - ROHC header compression stub
%
%   PDCP PDU header format (12-bit SN, data PDU, TS 38.323 Sec 6.2.2.2):
%     Byte 0: [D/C(1)=1][R(3)][SN_hi(4)]
%     Byte 1: [SN_lo(8)]
%
%   PDCP Control PDU (SN status report):
%     Byte 0: [D/C(1)=0][PDU_type(3)=000][R(4)]
%     Byte 1-2: [FMC(16)]   First Missing Count
%     Byte 3+:  bitmap of missing SNs
%
%   SL-SRB0 uses TM (no PDCP), SL-SRB1/2/3 use PDCP without ciphering by
%   default; SL-DRBs use PDCP with optional ciphering+integrity.
%
%   Usage:
%     pdcp = SidelinkPDCPEntity('SNBits', 12, 'BearerID', 1);
%     pdu  = pdcp.encapsulateSDU(sduBytes, priority);   % TX
%     [sdu, meta] = pdcp.decapsulatePDU(pduBytes);      % RX
%
%   References:
%     3GPP TS 38.323 v17.0.0 — NR; Packet Data Convergence Protocol

%   Copyright 2025. NR Sidelink Simulation Platform.

    properties
        SNBits               (1,1) double {mustBeMember(SNBits,[12,18])} = 12
        BearerID             (1,1) uint8  = 1    % DRB-ID or SRB-ID
        IntegrityProtection  (1,1) logical = false
        Ciphering            (1,1) logical = false
        ROHCEnabled          (1,1) logical = false
        DiscardTimer_ms      (1,1) double = inf  % PDCP SDU discard timer (ms)
    end

    properties (SetAccess = private)
        TxNextSN    (1,1) uint32 = 0   % TX COUNT = SN (simplified: no HFN)
        RxDelivered (1,1) uint32 = 0   % RX_DELIV: next in-order SN to deliver
        RxReorder   (1,1) uint32 = 0   % RX_REORD: SN that triggered reordering

        % RX reorder buffer: struct with fields sn_XXXXX = {sdu, meta}
        RxBuffer    = struct()

        % Stats
        TxPDUCount  (1,1) uint32 = 0
        RxPDUCount  (1,1) uint32 = 0
        DupDropped  (1,1) uint32 = 0
        IntegrityFail (1,1) uint32 = 0
    end

    properties (Dependent)
        SNModulus
        MaxSN
    end

    methods
        function obj = SidelinkPDCPEntity(varargin)
        %SidelinkPDCPEntity Construct with name-value pairs
            for i = 1:2:numel(varargin)
                obj.(varargin{i}) = varargin{i+1};
            end
        end

        function m = get.SNModulus(obj)
            m = 2^obj.SNBits;
        end

        function m = get.MaxSN(obj)
            m = obj.SNModulus - 1;
        end

        %% ----- TX path -----

        function pdu = encapsulateSDU(obj, sdu, priority)
        %encapsulateSDU Build a PDCP Data PDU from an SDU
        %   sdu:      uint8 byte vector (IP or V2X payload)
        %   priority: (optional) traffic priority hint (unused in header)
        %   Returns uint8 PDCP PDU byte vector.
            if nargin < 3; priority = 3; end %#ok<NASGU>
            sdu = uint8(sdu(:)');

            % Optional ROHC compression (stub — returns sdu unchanged)
            payload = obj.rohcCompress(sdu);

            % Build PDCP header
            sn  = obj.TxNextSN;
            hdr = obj.buildDataHeader(sn);

            % Assemble PDU
            pdu = [hdr, payload];

            % Optional integrity protection (stub — appends 4-byte MAC-I)
            if obj.IntegrityProtection
                mac_i = obj.computeMACI(pdu, sn);
                pdu   = [pdu, mac_i];
            end

            % Optional ciphering (stub — XOR with a zero keystream here)
            if obj.Ciphering
                pdu = obj.cipher(pdu, sn);
            end

            obj.TxNextSN  = uint32(mod(sn + 1, obj.SNModulus));
            obj.TxPDUCount = obj.TxPDUCount + 1;
        end

        %% ----- RX path -----

        function [sdu, meta] = decapsulatePDU(obj, pdu)
        %decapsulatePDU Decode a received PDCP PDU
        %   Returns sdu (uint8 bytes) and meta struct with SN, integrity status.
        %   Returns empty sdu if duplicate or integrity failure.
            sdu  = [];
            meta = struct('SN', 0, 'IntegrityOK', true, 'Duplicate', false);

            if isempty(pdu) || numel(pdu) < 2
                return;
            end
            pdu = uint8(pdu(:)');
            obj.RxPDUCount = obj.RxPDUCount + 1;

            dcBit = bitshift(bitand(pdu(1), uint8(128)), -7);
            if dcBit == 0
                % Control PDU (SN status report) — process and return
                obj.processControlPDU(pdu);
                return;
            end

            % Decipher
            if obj.Ciphering
                [sn, ~] = obj.parseSN(pdu);
                pdu = obj.decipher(pdu, sn);
            end

            % Verify integrity
            if obj.IntegrityProtection
                [valid, pdu] = obj.verifyMACI(pdu);
                if ~valid
                    obj.IntegrityFail = obj.IntegrityFail + 1;
                    meta.IntegrityOK = false;
                    return;  % Drop PDU
                end
            end

            % Parse header
            [sn, payStart] = obj.parseSN(pdu);
            meta.SN = sn;

            % Duplicate detection
            if obj.isDuplicate(sn)
                obj.DupDropped = obj.DupDropped + 1;
                meta.Duplicate = true;
                return;
            end

            % Extract payload and ROHC decompress
            payload = pdu(payStart:end);
            sdu = obj.rohcDecompress(payload);

            % In-order delivery / reorder buffer
            if sn == obj.RxDelivered
                % In-order: deliver immediately
                obj.RxDelivered = uint32(mod(obj.RxDelivered + 1, obj.SNModulus));
                obj.drainReorderBuffer();
            else
                % Out of order: buffer it
                key = sprintf('sn%u', sn);
                obj.RxBuffer.(key) = struct('sdu', sdu, 'sn', sn);
                sdu = [];  % Not delivered yet
            end
        end

        function statusPDU = buildSNStatusReport(obj)
        %buildSNStatusReport Generate PDCP SN Status Report PDU
        %   Used for re-establishment and handover (simplified).
            fmc = obj.RxDelivered;
            b0  = uint8(0);  % D/C=0, PDU_type=000
            b1  = uint8(bitshift(fmc, -8) & 255);
            b2  = uint8(fmc & 255);
            statusPDU = [b0, b1, b2];
        end

        function stats = getStats(obj)
        %getStats Return statistics struct
            stats = struct( ...
                'BearerID',       obj.BearerID, ...
                'TxPDUs',         obj.TxPDUCount, ...
                'RxPDUs',         obj.RxPDUCount, ...
                'DupDropped',     obj.DupDropped, ...
                'IntegrityFail',  obj.IntegrityFail, ...
                'TxNextSN',       obj.TxNextSN, ...
                'RxDelivered',    obj.RxDelivered);
        end

        function reset(obj)
        %reset Clear all state
            obj.TxNextSN   = 0;
            obj.RxDelivered = 0;
            obj.RxReorder  = 0;
            obj.RxBuffer   = struct();
            obj.TxPDUCount = 0;
            obj.RxPDUCount = 0;
            obj.DupDropped = 0;
            obj.IntegrityFail = 0;
        end
    end

    %% ----- Private helpers -----
    methods (Access = private)

        function hdr = buildDataHeader(obj, sn)
            % D/C=1 (data), R(3)=000, SN_hi, SN_lo
            if obj.SNBits == 12
                b0  = bitor(uint8(128), uint8(bitshift(sn,-8) & 15));
                b1  = uint8(sn & 255);
                hdr = [b0, b1];
            else  % 18-bit SN
                b0  = bitor(uint8(128), uint8(bitshift(sn,-16) & 3));
                b1  = uint8(bitshift(sn,-8) & 255);
                b2  = uint8(sn & 255);
                hdr = [b0, b1, b2];
            end
        end

        function [sn, payStart] = parseSN(obj, pdu)
            if obj.SNBits == 12
                sn = double(bitand(pdu(1), uint8(15))) * 256 + double(pdu(2));
                payStart = 3;
            else
                sn = double(bitand(pdu(1), uint8(3))) * 65536 + ...
                     double(pdu(2)) * 256 + double(pdu(3));
                payStart = 4;
            end
        end

        function dup = isDuplicate(obj, sn)
            % A SN is duplicate if it is below RxDelivered (window half-check)
            delta = mod(int32(sn) - int32(obj.RxDelivered), int32(obj.SNModulus));
            % If delta is in upper half of SN space, treat as old/duplicate
            dup = (delta >= int32(obj.SNModulus / 2));
        end

        function processControlPDU(~, ~)
            % Receive SN status report — update RxDelivered accordingly
            % (simplified: no action in this model)
        end

        function drainReorderBuffer(obj)
            cont = true;
            while cont
                key = sprintf('sn%u', obj.RxDelivered);
                if isfield(obj.RxBuffer, key)
                    entry = obj.RxBuffer.(key);
                    obj.RxDelivered = uint32(mod(obj.RxDelivered + 1, obj.SNModulus));
                    obj.RxBuffer = rmfield(obj.RxBuffer, key);
                    % In a full model, deliver entry.sdu to upper layer here
                    % (omitted for simulation — caller checks return value)
                    cont = true;
                else
                    cont = false;
                end
            end
        end

        % --- Security stubs (TS 33.536 / TS 38.323 Sec 5.9) ---

        function mac_i = computeMACI(~, pdu, ~)
            % Stub: SNOW 3G / AES-128-EIA / ZUC integrity
            % Returns 4-byte all-zeros MAC-I (no actual computation)
            mac_i = zeros(1, 4, 'uint8');
        end

        function [valid, pdu] = verifyMACI(~, pdu)
            % Stub: always passes in simulation
            valid = true;
            if numel(pdu) >= 4
                pdu = pdu(1:end-4);  % Strip 4-byte MAC-I
            end
        end

        function pdu = cipher(~, pdu, ~)
            % Stub: SNOW 3G / AES-128-EEA / ZUC ciphering (identity function)
        end

        function pdu = decipher(~, pdu, ~)
            % Stub: identity function
        end

        % --- ROHC stubs (TS 38.323 Sec 5.7) ---

        function pdu = rohcCompress(~, sdu)
            % Stub: no actual header compression (pass-through)
            pdu = sdu;
        end

        function sdu = rohcDecompress(~, pdu)
            % Stub: pass-through
            sdu = pdu;
        end
    end
end
