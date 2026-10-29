function rx = umRxInit(cfg, isGroupcastBroadcast)
%umRxInit Establish a receiving UM RLC entity.
%Spec:   TS 38.322 V16.3.0, clause 5.1.1 (establishment, including "For NR sidelink groupcast
%        and broadcast, when receiving the first UMD PDU from a Source Layer 2 ID and
%        Destination Layer 2 ID pair for an LCID ... establish a receiving RLC entity"),
%        clause 7.1 (UM receive state variables and their initial values), clause 7.3
%        (t-Reassembly: "only one t-Reassembly per RLC entity is running at a given time").
%Inputs: cfg                   struct from rlc.umConfig
%        isGroupcastBroadcast  logical -- selects the clause-7.1 initial value rule below
%Outputs: rx  scalar struct, all state explicit:
%            .cfg                   configuration
%            .RX_Next_Reassembly    integer -- clause 7.1 a)
%            .RX_Timer_Trigger      integer -- clause 7.1 b)
%            .RX_Next_Highest       integer -- clause 7.1 c)
%            .snInitialised         logical -- false only for a groupcast/broadcast entity
%                                   that has not yet seen a PDU carrying an SN
%            .tReassemblyExpiry     ms -- when t-Reassembly expires; -1 when not running
%            .buf                   reception buffer (rlc.rxBufInit)
%            .doneSn                1 x D integer -- SNs inside the window already reassembled
%                                   and delivered. Needed because clause 5.2.2.2.3 advances
%                                   RX_Next_Reassembly past SNs "reassembled and delivered",
%                                   and a delivered SDU's bytes are no longer in the buffer
%            .nPduDiscarded         integer -- PDUs discarded on receipt (invalid, or below
%                                   RX_Next_Reassembly)
%            .nSnAbandoned          integer -- SNs whose partial SDU was discarded by window
%                                   movement or t-Reassembly expiry: SDUs LOST in this entity
%
%THE GROUPCAST/BROADCAST INITIAL VALUE IS NOT ZERO
%-------------------------------------------------
%Clause 7.1: RX_Next_Reassembly and RX_Next_Highest are "initially set to 0. For groupcast and
%broadcast of NR sidelink communication, it is initially set to the SN of the first received
%UMD PDU containing an SN." A receiver that comes into range of an ongoing broadcast joins
%mid-stream at an arbitrary SN. Initialised to 0, a first SN of e.g. 40 lands 24 below 0 in a
%64-SN space -- inside [RX_Next_Highest - 32, RX_Next_Reassembly) -- and is DISCARDED, as is
%every SN until the stream happens to wrap into the window. The entity looks dead for up to a
%full SN cycle with no error anywhere.
%
%Timers are deadlines in ms, not countdowns: the entity holds no clock and reads the time only
%from its callers, so a run replays exactly.

if ~isstruct(cfg) || ~isfield(cfg, 'mode') || ~strcmp(cfg.mode, 'um')
    error('rlc:umRxInit:badCfg', 'umRxInit: cfg must come from rlc.umConfig');
end
rx = struct( ...
    'cfg',                cfg, ...
    'RX_Next_Reassembly', 0, ...
    'RX_Timer_Trigger',   0, ...
    'RX_Next_Highest',    0, ...
    'snInitialised',      ~logical(isGroupcastBroadcast), ...
    'tReassemblyExpiry',  -1, ...
    'buf',                rlc.rxBufInit(), ...
    'doneSn',             zeros(1, 0), ...
    'nPduDiscarded',      0, ...
    'nSnAbandoned',       0);
end
