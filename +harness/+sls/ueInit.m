function u = ueInit(ueId, scen)
%ueInit Per-UE state for the system-level simulator.
%Spec:   none -- an aggregation. Each field is created by the package that owns that state, so
%        nothing here duplicates a state machine.
%Inputs: ueId  integer, >=1
%        scen  from +harness/+sls/scenarioInit
%Outputs: u  scalar struct:
%   .ueId .posXY .srcL2Id .dstL2Id  identity and geometry
%   .lch     the MAC SAP, +sap/lchInit
%   .grant   the selected-grant lifecycle, +mac/grantInit
%   .harq    the HARQ entity, +mac/harqInit
%   .db      the sensing database, +phy/+ts38214/sensingDbInit
%   .nextPktId       integer -- monotonic packet counter
%   .trafficOffset   integer -- this UE's CAM phase within the generation period
%   .periodIdx       integer -- which reservation period of the current grant we are in, so
%                    grantOnPeriodEnd fires exactly once per period
%   .periodRefSlot   integer -- the logical slot the period count is measured from, fixed at
%                    selection. NOT read back off grant.txOppSlot(1): clause 5.22.1.2a's
%                    replacement can put a new resource EARLIER than the old anchor, and
%                    mac.grantReplaceResource re-sorts, so txOppSlot(1) moves under it
%   .nextProc        integer -- round-robin cursor over the Sidelink processes
%   .inFlight        struct array of contexts transmitted and not yet resolved
%   .inFlightProc    1 x n integer -- the HARQ process each in-flight context is riding
%   .peerUeId        integer -- the unicast peer, or 0 for broadcast
%   .prio            integer, 1..8 -- this UE's sl-Priority, from scen.prioByUe. 1 is HIGHEST
%   .psfchTx         struct array of PSFCH this UE owes, one per PSSCH it decoded and must
%                    acknowledge, scheduled at the slot psfchTiming picked
%   .psfchWait       struct array of PSFCH this UE is expecting back for its own transmissions
%   .curTb .curCtx .curProc .curNdi  the transport block currently in the HARQ buffer, its
%                    contexts, its Sidelink process and its NDI. Present and empty from the
%                    start rather than added on first use: a struct array whose elements grow
%                    different fields cannot be indexed, and MATLAB's error for it names the
%                    assignment rather than the cause.
%
%TRAFFIC PHASE IS STAGGERED BY UE
%--------------------------------
%offset = mod(ueId-1, periodSlots) rather than 0. Every UE generating in the same slot
%synchronises the whole scenario and manufactures a collision pattern that has nothing to do
%with the resource selection under measurement -- the KPI would then be reporting the traffic
%model.

% Mode-2 caps transmitting Sidelink processes at 4 for multiple MAC PDUs (TS 38.321 clause
% 5.22.1.3.1); harqInit's second argument carries that.
isPeriodicMode2 = true;

u = struct( ...
    'ueId',          ueId, ...
    'posXY',         scen.posXY(ueId, :), ...
    'srcL2Id',       ueId, ...
    'dstL2Id',       peerDst(ueId, scen), ...
    'peerUeId',      peerUe(ueId, scen), ...
    'prio',          scen.prioByUe(ueId), ...
    'lch',           sap.lchInit(scen.traffic.lcid, scen.prioByUe(ueId), peerDst(ueId, scen), 0, 0, scen.isUnicast), ...
    'grant',         mac.grantInit(), ...
    'harq',          mac.harqInit(4, isPeriodicMode2), ...
    'db',            phy.ts38214.sensingDbInit(), ...
    'nextPktId',     1, ...
    'trafficOffset', mod(ueId - 1, scen.traffic.periodSlots), ...
    'periodIdx',     0, ...
    'periodRefSlot', 0, ...
    'nextProc',      0, ...
    'inFlight',      repmat(sap.ctxInit(1, 0, 0, 1, 1, 1, 1, 0, 0), 1, 0), ...
    'inFlightProc',  zeros(1, 0), ...
    'psfchTx',       repmat(psfchTxTemplate(), 1, 0), ...
    'psfchWait',     repmat(psfchWaitTemplate(), 1, 0), ...
    'curTb',         false(0, 1), ...
    'curCtx',        repmat(sap.ctxInit(1, 0, 0, 1, 1, 1, 1, 0, 0), 1, 0), ...
    'curProc',       0, ...
    'curNdi',        0);
end

% =========================================================================
function d = peerDst(ueId, scen)
%peerDst This UE's Destination Layer-2 ID.
%Broadcast uses the all-ones identifier. Unicast pairs UEs in a RING -- UE i talks to UE i+1,
%and the last talks to the first -- rather than in disjoint pairs, so that every UE is both a
%transmitter and a receiver and the feedback path is exercised in both directions on every UE.
%Disjoint pairs would leave half the population never receiving.
if scen.isUnicast
    d = mod(ueId, scen.nUe) + 1;
else
    d = 2^24 - 1;
end
end

function p = peerUe(ueId, scen)
if scen.isUnicast
    p = mod(ueId, scen.nUe) + 1;
else
    p = 0;
end
end

function t = psfchTxTemplate()
%psfchTxTemplate One PSFCH this UE owes for a PSSCH it received.
t = struct('slot', 0, 'toUeId', 0, 'ack', false, 'procIdx', 0, ...
           'psschSlot', 0, 'startSubch', 0, 'srcL1Id', 0);
end

function t = psfchWaitTemplate()
%psfchWaitTemplate One PSFCH this UE expects back for a PSSCH it sent.
t = struct('slot', 0, 'fromUeId', 0, 'procIdx', 0);
end
