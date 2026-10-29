function rx = amRxInit(cfg)
%amRxInit Establish the receiving side of an AM RLC entity.
%Spec:   TS 38.322 V16.3.0, clause 5.1.1; clause 7.1 receive-side state variables (RX_Next,
%        RX_Highest_Status, RX_Next_Highest "initially set to 0"; RX_Next_Status_Trigger has no
%        stated initial value and is only read while t-Reassembly runs, which sets it);
%        clause 7.3 t-Reassembly and t-StatusProhibit. Re-establishment (5.1.2) is a fresh call.
%Inputs: cfg  struct from rlc.amConfig
%Outputs: rx  scalar struct, all state explicit:
%            .cfg                     configuration
%            .RX_Next .RX_Next_Status_Trigger .RX_Highest_Status .RX_Next_Highest
%                                     integers -- clause 7.1, verbatim
%            .tReassemblyExpiry       ms, -1 when not running
%            .tStatusProhibitExpiry   ms, -1 when not running
%            .statusTriggered         logical -- a STATUS report is owed (clause 5.3.4)
%            .pollDelayedSn           1 x P integer -- SNs of polls whose STATUS trigger is
%                                     delayed "until x < RX_Highest_Status or x >= RX_Next +
%                                     AM_Window_Size"
%            .buf                     reception buffer (rlc.rxBufInit)
%            .doneSn                  1 x D integer -- SNs in [RX_Next, RX_Next_Highest) whose
%                                     bytes have ALL been received (and so delivered). Needed
%                                     because a delivered SDU's bytes leave the buffer, but
%                                     clauses 5.2.3.2.2, 5.2.3.2.3 and 5.3.4 still ask whether
%                                     "all bytes ... have been received"
%            .nPduDiscarded           integer -- AMD PDUs discarded (invalid, outside the
%                                     window, or wholly duplicate)

if ~isstruct(cfg) || ~isfield(cfg, 'mode') || ~strcmp(cfg.mode, 'am')
    error('rlc:amRxInit:badCfg', 'amRxInit: cfg must come from rlc.amConfig');
end
rx = struct( ...
    'cfg',                    cfg, ...
    'RX_Next',                0, ...
    'RX_Next_Status_Trigger', 0, ...
    'RX_Highest_Status',      0, ...
    'RX_Next_Highest',        0, ...
    'tReassemblyExpiry',      -1, ...
    'tStatusProhibitExpiry',  -1, ...
    'statusTriggered',        false, ...
    'pollDelayedSn',          zeros(1, 0), ...
    'buf',                    rlc.rxBufInit(), ...
    'doneSn',                 zeros(1, 0), ...
    'nPduDiscarded',          0);
end
