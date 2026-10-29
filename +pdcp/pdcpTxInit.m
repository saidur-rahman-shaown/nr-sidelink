function tx = pdcpTxInit(cfg)
%pdcpTxInit Establish a transmitting sidelink PDCP entity.
%Spec:   TS 38.323 V16.8.0, clause 5.1.1 ("establish a PDCP entity for the radio bearer; set the
%        state variables of the PDCP entity to initial values"), clause 7.1 ("TX_NEXT ... The
%        initial value is 0"), clause 7.3 (discardTimer, "a new timer is started upon reception
%        of an SDU from upper layer").
%Inputs: cfg  struct from pdcp.pdcpConfig
%Outputs: tx  scalar struct, all state explicit:
%            .cfg         configuration
%            .TX_NEXT     integer, 0..2^32-1 -- COUNT of the next SDU (clause 7.1)
%            .discCount   1 x D integer -- COUNT of each SDU whose discardTimer is running
%            .discTag     1 x D integer -- the caller's tag for it (a packet-context index)
%            .discExpiry  1 x D real, ms -- when each discardTimer expires
%            .nTimerExpired  integer -- discardTimers that expired. NOT the loss count: an SDU
%                         RLC had already put on the air expires too and still arrives. Whether an
%                         expiry is a LOSS is decided by RLC's discard verdict (TS 38.322 clause
%                         5.4), so the caller counts losses from that -- +pdcp/CLAUDE.md asks for
%                         the count, and counting expiries would overstate it
%
%One timer per SDU, as clause 7.3 says, held as a deadline. With an infinite timer nothing is
%recorded at all -- the table would otherwise grow by one entry per SDU forever.

if ~isstruct(cfg) || ~isfield(cfg, 'format')
    error('pdcp:pdcpTxInit:badCfg', 'pdcpTxInit: cfg must come from pdcp.pdcpConfig');
end
tx = struct( ...
    'cfg',        cfg, ...
    'TX_NEXT',    0, ...
    'discCount',  zeros(1, 0), ...
    'discTag',    zeros(1, 0), ...
    'discExpiry', zeros(1, 0), ...
    'nTimerExpired', 0);
end
