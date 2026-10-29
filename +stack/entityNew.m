function e = entityNew()
%entityNew An empty PDCP + RLC + logical-channel entity record.
%Spec:   none -- a container. One record is one SLRB towards one peer: TS 38.323 5.1.1's PDCP
%        entity, TS 38.322 5.1.1's RLC entity, and the TS 38.321 5.22.1.4.1 logical channel.
%Outputs: e  scalar struct:
%   .peerL2Id   transmit: the Destination Layer-2 ID; receive: the Source Layer-2 ID it hears
%   .groupL2Id  receive side of groupcast/broadcast: the Destination Layer-2 ID; 0 for unicast
%   .cast       sdap.castCode
%   .rb         index into ue.rbs, 0 for a receive-only gc/bc entity (the receiver cannot know
%               the transmitter's SLRB)
%   .lcid       integer, 4..19
%   .mode       'um' or 'am'
%   .isTx .isRx logical
%   .pdcpTx .pdcpRx .rlcTx .rlcRx   the layer entities (empty struct where the side is absent)
%   .sdapHeader logical
%   .prio .pbr .bsd .harqFb .Sbj    logical channel parameters and its bucket

e = struct('peerL2Id', 0, 'groupL2Id', 0, 'cast', 0, 'rb', 0, 'lcid', 0, 'mode', '', ...
    'isTx', false, 'isRx', false, 'pdcpTx', struct(), 'pdcpRx', struct(), 'rlcTx', struct(), ...
    'rlcRx', struct(), 'sdapHeader', false, 'prio', 8, 'pbr', 0, 'bsd', 0, 'harqFb', false, 'Sbj', 0);
end
