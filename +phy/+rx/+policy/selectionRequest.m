function [req, feasible] = selectionRequest(n, mu, remainingPdb, prioTx, Cresel, p, pduBytes)
%selectionRequest Assemble phy.ts38214.candidateSet's `req` from policy choices.
%Spec:   none. Clause 8.1.4 opens by listing the parameters "the higher layer provides"; this
%        function is the higher layer's side of that handover, so every value it fills in is
%        either a policy choice (T1, T2, L_subCH, P_rsvp_TX) or passed straight through from
%        the MAC trigger (n, prio_TX, C_resel). It computes nothing normative.
%Inputs: n             integer, >=0 -- the triggering slot, as a LOGICAL pool slot index.
%                      +phy/+ts38214/ is the logical side of the mapping and never converts;
%                      neither does this function.
%        mu            integer, 0..3 -- mu_SL
%        remainingPdb  integer, >=0 -- remaining packet delay budget in **LOGICAL POOL SLOTS**.
%                      The three-step chain that produces it, in order:
%                        [remPhys, expired] = phy.rx.policy.remainingPdbSlots(pdbMs, tGen, now, mu)
%                        [remLogical, n]    = phy.rx.policy.pdbLogicalSlots(logicalOfPhys, now, remPhys)
%                        [req, feasible]    = phy.rx.policy.selectionRequest(n, mu, remLogical, ...)
%                      Skipping the middle step is correct only on a pool that holds every
%                      slot. See phy.rx.policy.pdbLogicalSlots.
%        prioTx        integer, 1..8 -- prio_TX, the L1 priority of the traffic that triggered
%                      selection. 1 is the HIGHEST (see +mac/CLAUDE.md).
%        Cresel        integer, >=1 -- C_resel from +mac/cresel. Must be 1 when p.prsvpTxMs
%                      is 0, per clause 8.1.4's aperiodic case.
%        p             scalar struct -- policy constants, normally phy.rx.policy.defaults()
%                      with .tbsBytesByLsubCH filled in. Passed in rather than fetched so an
%                      experiment can vary it per call and per UE without touching this
%                      function.
%        pduBytes      integer, >=1 -- the MAC PDU this grant must carry, INCLUDING subheaders.
%                      L_subCH is derived from it; see below.
%Outputs: req       scalar struct in exactly the shape candidateSet documents: .n .T1 .T2
%                   .remainingPdbSlots .LsubCH .prioTx .prsvpTxMs .Cresel
%         feasible  logical -- false when the PDB cannot accommodate even the processing time.
%                   `req` is still returned, fully formed, for logging the discard; the caller
%                   must not pass it to candidateSet.
%
%Everything here is an argument and nothing is read from a global or a file, so a call is
%reproducible from its arguments alone -- the property +harness/CLAUDE.md's determinism test
%depends on and the reason +mac/ takes its randomness as an input too.

if ~(mod(n, 1) == 0 && n >= 0)
    error('policy:selectionRequest:badN', 'selectionRequest: n must be a nonnegative integer logical slot index, got %s', num2str(n));
end
if ~(prioTx >= 1 && prioTx <= 8 && mod(prioTx, 1) == 0)
    error('policy:selectionRequest:badPrio', 'selectionRequest: prioTx must be an integer in 1..8, got %s', num2str(prioTx));
end
if ~(Cresel >= 1 && mod(Cresel, 1) == 0)
    error('policy:selectionRequest:badCresel', 'selectionRequest: Cresel must be an integer >= 1, got %s', num2str(Cresel));
end
if p.prsvpTxMs == 0 && Cresel ~= 1
    error('policy:selectionRequest:aperiodicCresel', 'selectionRequest: Cresel must be 1 when prsvpTxMs is 0 (aperiodic), got %s', num2str(Cresel));
end
% L_subCH IS DERIVED, NOT SUPPLIED. Clause 5.22.1.1 has the UE select "an amount of frequency
% resources", and the amount that matters is the one that carries the PDU at the chosen MCS.
% Deriving it here means there is no code path that selects a grant too small for its own data:
% subchannelsForTbs raises rather than returning a value that does not fit.
if isempty(p.tbsBytesByLsubCH)
    error('policy:selectionRequest:noTbsTable', 'selectionRequest: p.tbsBytesByLsubCH is empty; fill it from phy.ts38214.tbsDetermine at p.mcs before selecting a grant');
end
LsubCH = phy.rx.policy.subchannelsForTbs(pduBytes, p.tbsBytesByLsubCH);

[T1, T2, feasible] = phy.rx.policy.selectionWindow(mu, remainingPdb);

req = struct( ...
    'n',                 n, ...
    'T1',                T1, ...
    'T2',                T2, ...
    'remainingPdbSlots', remainingPdb, ...
    'LsubCH',            LsubCH, ...
    'prioTx',            prioTx, ...
    'prsvpTxMs',         p.prsvpTxMs, ...
    'Cresel',            Cresel);
end
