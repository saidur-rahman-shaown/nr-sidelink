function rx = pdcpRxInit(cfg)
%pdcpRxInit Establish a receiving sidelink PDCP entity.
%Spec:   TS 38.323 V16.8.0, clause 5.1.1 (establishment, including "for NR sidelink
%        communication for groupcast and broadcast, when receiving the first PDCP PDU, and there
%        is not yet a corresponding PDCP entity"), clause 7.1 (RX_NEXT, RX_DELIV, RX_REORD and
%        their initial values), clause 7.3 (t-Reordering, "only one t-Reordering per receiving
%        PDCP entity is running at a given time").
%Inputs: cfg  struct from pdcp.pdcpConfig. cfg.castType decides the initial-value rule
%Outputs: rx  scalar struct, all state explicit:
%            .cfg                 configuration
%            .RX_NEXT .RX_DELIV .RX_REORD   COUNT values, 0..2^32-1 -- clause 7.1, verbatim
%            .initialised         logical -- false for a groupcast/broadcast entity until its
%                                 first PDU sets the state variables (see pdcpRxPdu)
%            .tReorderingExpiry   ms, -1 when not running
%            .bufCount            1 x B integer -- COUNT of each SDU in the reception buffer
%            .bufLen              1 x B integer -- its length in octets
%            .bufDelivered        1 x B logical -- already delivered out of order (clause
%                                 5.2.2.1's outOfOrderDelivery branch) but still held, because
%                                 RX_DELIV has not passed it and duplicate detection needs it
%            .bufData             1 x sum(bufLen) octets, concatenated in buffer order
%            .nDiscarded          integer -- PDUs discarded (invalid, duplicate, or COUNT below
%                                 RX_DELIV)
%
%Unicast entities start at 0. Groupcast/broadcast entities cannot: the receiver may arrive at
%any point in a stream, and clause 7.1 sets their state from the first SN it hears.

if ~isstruct(cfg) || ~isfield(cfg, 'format')
    error('pdcp:pdcpRxInit:badCfg', 'pdcpRxInit: cfg must come from pdcp.pdcpConfig');
end
rx = struct( ...
    'cfg',               cfg, ...
    'RX_NEXT',           0, ...
    'RX_DELIV',          0, ...
    'RX_REORD',          0, ...
    'initialised',       strcmp(cfg.castType, 'unicast'), ...
    'tReorderingExpiry', -1, ...
    'bufCount',          zeros(1, 0), ...
    'bufLen',            zeros(1, 0), ...
    'bufDelivered',      false(1, 0), ...
    'bufData',           zeros(1, 0), ...
    'nDiscarded',        0);
end
