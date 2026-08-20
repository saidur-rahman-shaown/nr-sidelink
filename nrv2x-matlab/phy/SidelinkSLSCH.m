classdef SidelinkSLSCH < handle
%SidelinkSLSCH NR Sidelink Shared Channel (SL-SCH) transport channel
%   Implements SL-SCH transport channel processing per TS 38.212 Sec 8.1
%   and TBS determination per TS 38.214 Sec 8.1.3.2.
%
%   SL-SCH reuses the UL-SCH coding chain:
%   TX: TB CRC → CB segmentation → LDPC encode → Rate match → CB concat
%   RX: Rate recover → LDPC decode → CB desegment → TB CRC check
%
%   Wraps 5G Toolbox nrULSCH (encoder) and nrDLSCHDecoder (decoder).
%
%   Properties:
%     MultipleHARQProcesses - Per-HARQ-ID soft buffer (default true)
%     TargetCodeRate        - Code rate for encoding (default 308/1024)
%     LDPCDecodingAlgorithm - LDPC decoder algorithm (default 'Normalized min-sum')
%     MaxLDPCIterations     - Max LDPC iterations (default 6)
%
%   Methods:
%     encode           - Encode TB into SL-SCH codeword
%     decode           - Decode soft bits into TB
%     getTBS           - Compute TBS per TS 38.214 Sec 8.1.3.2
%     setTransportBlock- Store TB for encoding
%     getTransportBlock- Retrieve stored TB
%     resetSoftBuffer  - Clear decoder soft buffer for HARQ process

%   Copyright 2025. NR Sidelink Simulation Platform.
%   Spec refs: TS 38.212 Sec 6.2 (UL-SCH coding chain), Sec 8.1 (SL-SCH)
%              TS 38.214 Sec 8.1.3.2 (SL-SCH TBS determination)

    properties
        MultipleHARQProcesses (1,1) logical = true
        TargetCodeRate        (1,1) double  = 308/1024
        LDPCDecodingAlgorithm (1,:) char    = 'Normalized min-sum'
        MaxLDPCIterations     (1,1) {mustBePositive,mustBeInteger} = 6
    end

    properties (SetAccess = private)
        Encoder     % nrULSCH encoder object (5G Toolbox)
        Decoder     % nrDLSCHDecoder object (5G Toolbox)
    end

    methods
        function obj = SidelinkSLSCH(varargin)
            for i = 1:2:numel(varargin)
                obj.(varargin{i}) = varargin{i+1};
            end
            obj.initEncoder();
            obj.initDecoder();
        end

        function cw = encode(obj, trBlk, modulation, numLayers, outLen, rv, harqID)
        %encode Encode transport block to SL-SCH codeword
        %   CW = encode(SLSCH, TB, MOD, NLAYERS, G, RV, HARQID)
        %   Processing: TB CRC → CB seg → LDPC → Rate match → CB concat
            obj.Encoder.TargetCodeRate = obj.TargetCodeRate;
            obj.Encoder.setTransportBlock(trBlk, harqID);
            if obj.MultipleHARQProcesses
                cw = obj.Encoder(modulation, numLayers, outLen, rv, harqID);
            else
                cw = obj.Encoder(modulation, numLayers, outLen, rv);
            end
        end

        function [trBlk, blkErr] = decode(obj, softBits, modulation, numLayers, rv, harqID)
        %decode Decode soft bits to transport block with HARQ combining
        %   [TB, ERR] = decode(SLSCH, LLR, MOD, NLAYERS, RV, HARQID)
        %   Soft buffer combining across retransmissions is automatic.
            obj.Decoder.TargetCodeRate = obj.TargetCodeRate;
            if obj.MultipleHARQProcesses
                [trBlk, blkErr] = obj.Decoder(softBits, modulation, numLayers, rv, harqID);
            else
                [trBlk, blkErr] = obj.Decoder(softBits, modulation, numLayers, rv);
            end
        end

        function tbs = getTBS(~, modulation, numLayers, nre, targetCodeRate)
        %getTBS Compute SL-SCH TBS per TS 38.214 Sec 8.1.3.2
        %   TBS = getTBS(~, MOD, NLAYERS, NRE, TCR)
        %   Uses nrTBS with nPRB=nre, nREPerPRB=1 to bypass internal calc.
            tbs = nrTBS(modulation, numLayers, nre, 1, targetCodeRate);
        end

        function setTransportBlock(obj, trBlk, harqID)
            if nargin < 3, harqID = 0; end
            obj.Encoder.setTransportBlock(trBlk, harqID);
        end

        function trBlk = getTransportBlock(obj, harqID)
            if nargin < 2, harqID = 0; end
            trBlk = obj.Encoder.getTransportBlock(harqID);
        end

        function resetSoftBuffer(obj, harqID)
            obj.Decoder.resetSoftBuffer(harqID);
        end

        function reset(obj)
            obj.initEncoder();
            obj.initDecoder();
        end
    end

    methods (Access = private)
        function initEncoder(obj)
            obj.Encoder = nrULSCH;
            obj.Encoder.MultipleHARQProcesses = obj.MultipleHARQProcesses;
            obj.Encoder.TargetCodeRate = obj.TargetCodeRate;
            % TS 38.212 Sec 8.2: SL-SCH rate matching per clause 6.2.5
            % with I_LBRM = 0 (limited buffer rate matching always off).
            % nrULSCH default is already false; set explicitly if supported.
            if isprop(obj.Encoder, 'LimitedBufferRateMatching')
                obj.Encoder.LimitedBufferRateMatching = false;
            end
        end
        function initDecoder(obj)
            obj.Decoder = nrDLSCHDecoder;
            obj.Decoder.MultipleHARQProcesses = obj.MultipleHARQProcesses;
            obj.Decoder.TargetCodeRate = obj.TargetCodeRate;
            obj.Decoder.LDPCDecodingAlgorithm = obj.LDPCDecodingAlgorithm;
            obj.Decoder.MaximumLDPCIterationCount = obj.MaxLDPCIterations;
            % TS 38.212 Sec 8.2: I_LBRM = 0 for SL-SCH.
            % nrDLSCHDecoder default is already false; set if supported.
            if isprop(obj.Decoder, 'LimitedBufferRateMatching')
                obj.Decoder.LimitedBufferRateMatching = false;
            end
        end
    end
end
