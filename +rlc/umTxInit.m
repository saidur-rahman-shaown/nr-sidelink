function tx = umTxInit(cfg)
%umTxInit Establish a transmitting UM RLC entity.
%Spec:   TS 38.322 V16.3.0, clause 5.1.1 ("establish a RLC entity; set the state variables of
%        the RLC entity to initial values"), clause 7.1 ("TX_Next - UM send state variable ...
%        It is initially set to 0"). Re-establishment (clause 5.1.2) is a fresh call to this
%        function: it discards every SDU and resets every variable, which is exactly what
%        clause 5.1.2 lists.
%Inputs: cfg  struct from rlc.umConfig
%Outputs: tx  scalar struct, all state explicit:
%            .cfg        the configuration
%            .TX_Next    integer, 0..2^snFieldLength-1 -- clause 7.1
%            .buf        1 x B octets -- queued SDUs, concatenated in arrival order
%            .sduLen     1 x N integer -- byte length of each queued SDU
%            .sduTag     1 x N integer -- caller's identifier for each SDU (e.g. a packet
%                        context index); RLC never interprets it, it only carries it to the
%                        PDUs so a KPI can follow a packet through segmentation
%            .sduOffset  1 x N integer -- bytes of each SDU already submitted to lower layer,
%                        i.e. the SO of its next segment. Non-zero only for the head SDU
%            .sduSn      1 x N integer -- SN given to a segmented SDU, -1 until segmented

if ~isstruct(cfg) || ~isfield(cfg, 'mode') || ~strcmp(cfg.mode, 'um')
    error('rlc:umTxInit:badCfg', 'umTxInit: cfg must come from rlc.umConfig');
end
tx = struct( ...
    'cfg',       cfg, ...
    'TX_Next',   0, ...
    'buf',       zeros(1, 0), ...
    'sduLen',    zeros(1, 0), ...
    'sduTag',    zeros(1, 0), ...
    'sduOffset', zeros(1, 0), ...
    'sduSn',     zeros(1, 0));
end
