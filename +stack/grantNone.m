function gr = grantNone()
%grantNone An empty dynamic Mode-2 grant.
%Spec:   TS 38.321 V16.22.0 clause 5.22.1.1, the "selected sidelink grant" for transmission of a
%        single MAC PDU (no reservation period): the initial resource and up to
%        sl-MaxNumPerReserve-1 chained retransmission resources, all of width L_subCH.
%Outputs: gr  scalar struct:
%   .active   logical
%   .peerL2Id .cast   the Destination the grant was selected for
%   .slots    1 x N integer -- logical (= physical here) slots, ascending; slots(1) carries the SCI
%   .subch    1 x N integer -- starting sub-channel of each
%   .L        integer -- L_subCH
%   .next     integer -- index of the next unused resource
%   .proc     integer -- the Sidelink process holding the MAC PDU, 0 before the first transmission
%   .ndi .prio .harqFb  what the SCI signals for this MAC PDU
%   .tb .lcids .sduLen  the MAC PDU, kept for the blind retransmissions of the same grant
%   .isPeriodic   logical -- a grant for multiple MAC PDUs (SPS, TS 38.321 5.22.1.1)
%   .prsvpMs      P_rsvp_TX, ms (0 when dynamic); .periodSlots  P'_rsvp_TX, logical slots
%   .mg           the MAC lifecycle state (mac.grantInit/grantSelect): counter, keep draw,
%                 unused periods. .slots/.subch hold the CURRENT period's resources
%   .periodIdx    reservation periods elapsed since selection (0 in the first): from the second
%                 period on, every resource was announced by the previous period's SCI-1A
%   .selPrio      priority of the data the grant was selected for (prio_TX of re-evaluation and
%                 pre-emption before the MAC PDU, and its own priority, exist)
%   .minGap       the minimum time gap between resources applied at selection (TS 38.321 5.22.1.1)
%   .keepDrawPre  the sl-ProbResourceKeep draw for the last period, made when the counter reaches
%                 1 so SCI-1A can announce 0 ms there if the grant will not be kept

gr = struct('active', false, 'peerL2Id', 0, 'cast', 0, 'slots', zeros(1, 0), 'subch', zeros(1, 0), ...
    'L', 0, 'next', 1, 'proc', 0, 'ndi', 0, 'prio', 8, 'harqFb', false, ...
    'tb', false(0, 1), 'lcids', zeros(1, 0), 'sduLen', zeros(1, 0), ...
    'isPeriodic', false, 'prsvpMs', 0, 'periodSlots', 0, 'mg', mac.grantInit(), 'keepDrawPre', NaN, ...
    'periodIdx', 0, 'selPrio', 8, 'minGap', 0);
end
