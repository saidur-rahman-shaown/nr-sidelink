classdef ChannelGraph < handle
%ChannelGraph Multi-UE deployment as a graph: nodes = UEs, edges = channels.
%
%   Every UE is a node (ID, L2 ID, 2-D position). Every UE pair is an
%   edge holding the large-scale channel state of that link:
%     distance -> 3GPP TR 38.901 RMa pathloss (sidelinkPathLoss.m, the
%     distance-based rural-macrocell model, LOS or NLOS) + a lognormal
%     shadow-fading draw with the model's sigma_SF, drawn ONCE per edge
%     (static large-scale state) from the seeded RandStream.
%
%   The harness queries an edge for the link RSRP:
%       rsrp = g.linkRSRP(txID, rxID)      % TxPower - PL - SF  [dBm]
%   and feeds it into the receiving UE's SensingDatabase — the sensing
%   threshold comparisons of TS 38.214 8.1.4 then run on channel-derived
%   numbers instead of constants.
%
%   asGraph() returns a MATLAB graph object (nodes/edges/weights) for
%   inspection and plotting; adjacencyRSRP() the N x N RSRP matrix.
%
%   Edges are symmetric (reciprocal channel). Positions can be updated
%   (mobility); pathloss follows position, shadow fading stays the edge's
%   static draw — swap in a correlated-SF model later if drops need it.

    properties
        Fc_Hz       = 5.9e9        % band n47
        Model       = 'RMa-LOS'    % 'RMa-LOS' | 'RMa-NLOS' | 'FSPL'
        TxPower_dBm = 23           % power class 3 (matches RFModule)
        AntennaGain_dBi = 0
    end

    properties (SetAccess = private)
        IDs   = []                 % 1 x N UE IDs
        L2IDs = []                 % 1 x N layer-2 IDs
        Pos   = zeros(0, 2)        % N x 2 positions [m]
        SF_dB = []                 % N x N symmetric shadow fading draws
        rs                         % RandStream
    end

    methods
        function obj = ChannelGraph(rs)
            if nargin < 1, rs = RandStream('mt19937ar', 'Seed', 1); end
            obj.rs = rs;
        end

        function addNode(obj, id, l2id, pos)
            %addNode Add a UE node; draws shadow fading to existing nodes.
            assert(~any(obj.IDs == id), 'ChannelGraph:dupNode', ...
                'UE %d already in the graph', id);
            obj.IDs(end+1)   = id;
            obj.L2IDs(end+1) = l2id;
            obj.Pos(end+1, :) = pos(:)';
            N = numel(obj.IDs);
            % grow SF matrix; one static lognormal draw per new edge
            [~, ~, sigma] = sidelinkPathLoss(100, obj.Fc_Hz, obj.Model);
            newSF = sigma * randn(obj.rs, 1, N-1);
            obj.SF_dB(N, 1:N-1) = newSF;
            obj.SF_dB(1:N-1, N) = newSF';
            obj.SF_dB(N, N) = 0;
        end

        function setPosition(obj, id, pos)
            obj.Pos(obj.idx(id), :) = pos(:)';
        end

        function [pl, sf, d] = edge(obj, idA, idB)
            %edge Large-scale channel state of the link A<->B.
            a = obj.idx(idA);  b = obj.idx(idB);
            assert(a ~= b, 'ChannelGraph:selfEdge', 'no self edges');
            d  = norm(obj.Pos(a, :) - obj.Pos(b, :));
            pl = sidelinkPathLoss(d, obj.Fc_Hz, obj.Model);
            sf = obj.SF_dB(a, b);
        end

        function rsrp = linkRSRP(obj, txID, rxID)
            %linkRSRP Abstract SL RSRP on the edge tx->rx [dBm].
            [pl, sf] = obj.edge(txID, rxID);
            rsrp = obj.TxPower_dBm + 2*obj.AntennaGain_dBi - pl - sf;
        end

        function A = adjacencyRSRP(obj)
            %adjacencyRSRP N x N link RSRP matrix (NaN diagonal).
            N = numel(obj.IDs);
            A = nan(N);
            for a = 1:N
                for b = a+1:N
                    r = obj.linkRSRP(obj.IDs(a), obj.IDs(b));
                    A(a, b) = r;  A(b, a) = r;
                end
            end
        end

        function G = asGraph(obj)
            %asGraph MATLAB graph object: node names = UE/L2 IDs,
            %   edge weights = link RSRP [dBm].
            N = numel(obj.IDs);
            [ii, jj] = find(triu(ones(N), 1));
            w = zeros(numel(ii), 1);
            for k = 1:numel(ii)
                w(k) = obj.linkRSRP(obj.IDs(ii(k)), obj.IDs(jj(k)));
            end
            names = arrayfun(@(id, l2) sprintf('UE%d (L2 %d)', id, l2), ...
                obj.IDs, obj.L2IDs, 'UniformOutput', false);
            G = graph(ii, jj, w, names);
        end
    end

    methods (Access = private)
        function k = idx(obj, id)
            k = find(obj.IDs == id, 1);
            assert(~isempty(k), 'ChannelGraph:unknownNode', 'UE %d not in graph', id);
        end
    end
end
