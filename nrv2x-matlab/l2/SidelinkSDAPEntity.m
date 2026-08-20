classdef SidelinkSDAPEntity < handle
%SidelinkSDAPEntity Functional NR sidelink SDAP entity.
%   Maps PC5 QoS flows to sidelink radio bearers and adds/removes a compact
%   SDAP data PDU header. This is a practical user-plane SDAP model for the
%   simulator; it keeps the QFI visible across the layer boundary so PDCP,
%   RLC, MAC, and PHY can remain separately testable.

    properties
        DefaultQFI (1,1) uint8 = 1
        HeaderPresent (1,1) logical = true
    end

    properties (SetAccess = private)
        Mappings = struct.empty(0,1)
        TxSDUs (1,1) uint32 = 0
        RxSDUs (1,1) uint32 = 0
    end

    methods
        function obj = SidelinkSDAPEntity(varargin)
            for i = 1:2:numel(varargin)
                obj.(varargin{i}) = varargin{i+1};
            end
        end

        function addMapping(obj, varargin)
        %addMapping Add or replace a QFI -> DRB/LCID/PQI mapping.
            p = inputParser;
            addParameter(p, 'QFI', double(obj.DefaultQFI));
            addParameter(p, 'DRBID', 1);
            addParameter(p, 'LCID', 3);
            addParameter(p, 'PQI', 55);
            addParameter(p, 'Priority', 3);
            addParameter(p, 'CastType', 'broadcast');
            addParameter(p, 'GFBRbps', 0);
            addParameter(p, 'MFBRbps', inf);
            addParameter(p, 'ServiceLabel', 'data');
            parse(p, varargin{:});
            r = p.Results;

            mapping = struct( ...
                'QFI', uint8(r.QFI), ...
                'DRBID', uint8(r.DRBID), ...
                'LCID', uint8(r.LCID), ...
                'PQI', uint8(r.PQI), ...
                'Priority', uint8(r.Priority), ...
                'CastType', char(r.CastType), ...
                'GFBRbps', r.GFBRbps, ...
                'MFBRbps', r.MFBRbps, ...
                'ServiceLabel', char(r.ServiceLabel));

            idx = obj.findMappingIdx(mapping.QFI);
            if isempty(idx)
                if isempty(obj.Mappings)
                    obj.Mappings = mapping;
                else
                    obj.Mappings(end+1,1) = mapping;
                end
            else
                obj.Mappings(idx) = mapping;
            end
        end

        function mapping = getMapping(obj, qfi)
        %getMapping Resolve the bearer mapping for a QFI.
            if nargin < 2 || isempty(qfi)
                qfi = obj.DefaultQFI;
            end
            idx = obj.findMappingIdx(uint8(qfi));
            if isempty(idx)
                if isempty(obj.Mappings)
                    obj.addMapping('QFI', qfi);
                    idx = obj.findMappingIdx(uint8(qfi));
                else
                    idx = 1;
                end
            end
            mapping = obj.Mappings(idx);
        end

        function [sdapPDU, mapping, meta] = encapsulateSDU(obj, sdu, varargin)
        %encapsulateSDU Add SDAP header and select bearer mapping.
            p = inputParser;
            addParameter(p, 'QFI', double(obj.DefaultQFI));
            addParameter(p, 'RQI', false);
            addParameter(p, 'RDI', false);
            parse(p, varargin{:});

            qfi = uint8(bitand(uint8(p.Results.QFI), uint8(63)));
            mapping = obj.getMapping(qfi);
            sdu = uint8(sdu(:)');

            if obj.HeaderPresent
                hdr = bitor(qfi, uint8(p.Results.RQI) * uint8(64));
                hdr = bitor(hdr, uint8(p.Results.RDI) * uint8(128));
                sdapPDU = [hdr, sdu];
            else
                sdapPDU = sdu;
            end

            meta = struct('QFI', qfi, 'RQI', logical(p.Results.RQI), ...
                'RDI', logical(p.Results.RDI), 'DRBID', mapping.DRBID, ...
                'LCID', mapping.LCID, 'PQI', mapping.PQI, ...
                'Priority', mapping.Priority, 'CastType', mapping.CastType);
            obj.TxSDUs = obj.TxSDUs + 1;
        end

        function [sdu, meta] = decapsulatePDU(obj, sdapPDU)
        %decapsulatePDU Strip SDAP header and return QoS metadata.
            sdu = uint8([]);
            meta = struct('QFI', obj.DefaultQFI, 'RQI', false, 'RDI', false);
            if isempty(sdapPDU)
                return;
            end
            sdapPDU = uint8(sdapPDU(:)');
            if obj.HeaderPresent
                b0 = sdapPDU(1);
                meta.QFI = bitand(b0, uint8(63));
                meta.RQI = logical(bitand(b0, uint8(64)));
                meta.RDI = logical(bitand(b0, uint8(128)));
                sdu = sdapPDU(2:end);
            else
                sdu = sdapPDU;
            end
            obj.RxSDUs = obj.RxSDUs + 1;
        end

        function stats = getStats(obj)
            stats = struct('TxSDUs', obj.TxSDUs, 'RxSDUs', obj.RxSDUs, ...
                'NumMappings', numel(obj.Mappings), 'HeaderPresent', obj.HeaderPresent);
        end

        function reset(obj)
            obj.TxSDUs = 0;
            obj.RxSDUs = 0;
        end
    end

    methods (Access = private)
        function idx = findMappingIdx(obj, qfi)
            idx = [];
            if isempty(obj.Mappings)
                return;
            end
            ids = [obj.Mappings.QFI];
            pos = find(ids == uint8(qfi), 1);
            if ~isempty(pos)
                idx = pos;
            end
        end
    end
end
