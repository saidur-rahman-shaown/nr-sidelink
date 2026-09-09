function [needsReselect, checkedIdx] = reevaluation(grantSlot, grantStartSubch, signalledBySci, currentSlot, T3, candY, candX, survivor)
%reevaluation Re-evaluation check for not-yet-signalled grant resources, TS 38.321 clause 5.22.1.2a.
%Spec:   TS 38.321 V16.22.0, clause 5.22.1.2a: "A resource(s) of the selected sidelink grant for
%        a MAC PDU to transmit from multiplexing and assembly entity is re-evaluated by physical
%        layer at T_3 before the slot where the SCI indicating the resource(s) is signalled AT
%        FIRST TIME as specified in clause 8.1.4 of TS 38.214 [7]. [...] For re-evaluation, m is
%        the slot where the SCI indicating the resource(s) is signalled at first time." And the
%        action: "if a resource(s) of the selected sidelink grant WHICH HAS NOT BEEN IDENTIFIED
%        BY A PRIOR SCI is indicated for re-evaluation by the physical layer [...]: remove the
%        resource(s) from the selected sidelink grant [...]; randomly select the time and
%        frequency resource from the resources indicated by the physical layer [...]; replace the
%        removed or dropped resource(s) by the selected resource(s)."
%Inputs: grantSlot        1 x nRes integer row vector -- logical pool slot of each resource in the
%                         selected sidelink grant
%        grantStartSubch  1 x nRes integer row vector -- starting sub-channel of each
%        signalledBySci   1 x nRes logical row vector -- whether each resource has ALREADY been
%                         announced by a prior SCI. Re-evaluation applies ONLY where this is
%                         false; the true ones are pre-emption's business instead.
%        currentSlot      integer -- the logical pool slot the check is being run in
%        T3              positive integer, slots -- the re-evaluation lead time. Clause 5.22.1.2a
%                         places the check "at T_3 before" slot m; TS 38.214 clause 8.1.4 defines
%                         T_3 as T_proc,1^SL, so callers pass +phy/+ts38214/procTimeSelection(mu).
%                         NOTE 1 permits latitude ("it is up to UE implementation to re-evaluate
%                         or pre-empt before 'm - T_3' or after 'm - T_3' but before 'm'"), so
%                         this is the earliest check point, not the only legal one.
%        candY, candX     1 x Mtotal integer row vectors -- the candidate enumeration currently
%                         reported by +phy/+ts38214/candidateSet
%        survivor         1 x Mtotal logical row vector -- candidateSet's S_A membership
%Outputs: needsReselect  1 x nRes logical row vector -- true for each grant resource that must be
%                        removed and replaced. False for every resource that is not due for a
%                        check yet, that has already been signalled, or that is still in S_A.
%         checkedIdx     1 x nRes logical row vector -- which resources were actually examined
%                        this call, i.e. reached their m - T_3 point and were not yet signalled.
%                        Returned so a caller can tell "checked and fine" from "not checked yet";
%                        without it, needsReselect all-false is ambiguous.
%
%The definition of m is what separates this from preemption, and it is the whole reason the two
%are different modules rather than one with a flag. Here m is the slot where the SCI FIRST
%ANNOUNCES the resource -- so the check happens before the UE has committed to the resource
%publicly, and the question is "is my intended resource still a good choice?". In pre-emption m is
%the slot where the resource IS LOCATED, the announcement has already gone out, and the question
%is "has someone higher-priority taken it from under me?". Different m, different trigger,
%different resource set, and +mac/CLAUDE.md's second known trap says plainly: "Re-evaluation and
%pre-emption operate on different resource sets with different timing. Never merge them; never
%let one call the other."
%
%A resource is flagged when it is NO LONGER IN S_A. That is the "indicated for re-evaluation by
%the physical layer" condition of clause 8.1.4 expressed in terms of what candidateSet actually
%returns: the UE re-runs selection, and any of its own not-yet-announced picks that have dropped
%out of the fresh candidate set have to be replaced. A resource that is not in the enumeration at
%all counts as dropped too -- it fell outside the current selection window, which is a stronger
%form of the same thing.
%
%This function only IDENTIFIES resources to replace. Choosing the replacements is clause
%5.22.1.2a's "randomly select [...] from the resources indicated by the physical layer", i.e. a
%uniform draw from S_A subject to the minimum time gap and the constraint that the resource "can
%be indicated by the time resource assignment of an SCI for a retransmission" -- a UE
%implementation policy that lives in +phy/+rx/+policy/, the same split candidateSet applies to
%T1/T2. NOTE 3 also leaves it open whether to reselect other pre-selected-but-unreserved
%resources at the same time; this function does not.
nRes = numel(grantSlot);
if ~isrow(grantSlot) || ~isequal(size(grantStartSubch), size(grantSlot)) || ~isequal(size(signalledBySci), size(grantSlot))
    error('mac:reevaluation:badGrant', 'reevaluation: grantSlot, grantStartSubch and signalledBySci must be row vectors of the same length');
end
if ~isrow(candY) || ~isequal(size(candX), size(candY)) || ~isequal(size(survivor), size(candY))
    error('mac:reevaluation:badCandidates', 'reevaluation: candY, candX and survivor must be row vectors of the same length');
end
if T3 < 1 || mod(T3, 1) ~= 0
    error('mac:reevaluation:badT3', 'reevaluation: T3 must be a positive integer number of slots (T_proc,1^SL from procTimeSelection), got %s', num2str(T3));
end
signalledBySci = logical(signalledBySci);
survivor = logical(survivor);

needsReselect = false(1, nRes);
checkedIdx = false(1, nRes);
for i = 1:nRes
    if signalledBySci(i)
        continue;   % already announced by a prior SCI -> pre-emption's resource set, not this one
    end
    % clause 5.22.1.2a: the check happens at T_3 before m, where m is the first-signalling slot.
    if currentSlot < grantSlot(i) - T3
        continue;   % not yet due
    end
    checkedIdx(i) = true;
    inSA = any(candY == grantSlot(i) & candX == grantStartSubch(i) & survivor);
    needsReselect(i) = ~inSA;
end
end
