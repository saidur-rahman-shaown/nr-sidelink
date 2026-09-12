function [h, nReleased] = harqRxAge(h, nowSlot, staleAfterSlots)
%harqRxAge Release receive processes whose reception has stopped advancing.
%Spec:   TS 38.321 V16.22.0, clause 5.22.2.2.1 NOTE 1 -- "If there is no unoccupied Sidelink
%        process in the Sidelink HARQ entity, how to manage receiving Sidelink processes is up
%        to UE implementation." Clause 5.22.2.2.2 releases a process on the first SUCCESSFUL
%        decode and says nothing about a reception that never succeeds, so a policy is required
%        and this is it. Nothing here is normative.
%Inputs: h                struct from mac.harqRxInit
%        nowSlot          integer, >=0 -- current logical pool slot
%        staleAfterSlots  integer, >=1 -- release a process that has received nothing for this
%                         many slots. Should exceed the longest gap a transmitter can leave
%                         between the transmissions of one TB: its reservation period, times
%                         the retransmission count it may still spend
%Outputs: h          updated entity
%         nReleased  integer -- how many processes were freed, so a caller can count it
%
%WITHOUT THIS THE ENTITY FILLS AND RECEPTION STOPS, SILENTLY
%-------------------------------------------------------------
%A transport block that never decodes keeps its soft buffer and its process indefinitely: the
%only release the clause specifies is on success. In a sparse pool that is harmless; in a dense
%one it is fatal, and it fails in the direction that hides it. Measured before this function
%existed, at 2000 slots: the worst UE held 4 of 16 processes at 20 UEs, **16 of 16 at 50 UEs**,
%and 91% of all processes were occupied pool-wide at 80 UEs. Past that point harqRxAssign
%returns procIdx = 0 and drops transport blocks that WOULD have decoded -- so reception degrades
%as density rises, which reads as congestion or a bad channel rather than as a receiver running
%out of state.
%
%The staleness bound is a policy, not a deadline in any clause. It has to be longer than the
%legitimate gap between a TB's transmissions -- otherwise a process is released while its own
%retransmission is still in flight, throwing away the soft buffer that was about to complete it
%-- and short enough that a permanently-failed reception does not outlive the traffic that
%caused it. A reservation period times the maximum retransmission count is the natural scale.

if ~(nowSlot >= 0 && mod(nowSlot, 1) == 0)
    error('mac:harqRxAge:badSlot', 'harqRxAge: nowSlot must be a nonnegative integer, got %s', num2str(nowSlot));
end
if ~(staleAfterSlots >= 1 && mod(staleAfterSlots, 1) == 0)
    error('mac:harqRxAge:badStale', 'harqRxAge: staleAfterSlots must be a positive integer, got %s', num2str(staleAfterSlots));
end

stale = h.occupied & (h.lastSlot >= 0) & (nowSlot - h.lastSlot > staleAfterSlots);
nReleased = nnz(stale);

h.occupied(stale)  = false;
h.srcId(stale)     = 0;
h.dstId(stale)     = 0;
h.harqId(stale)    = -1;
h.lastNdi(stale)   = -1;
h.decoded(stale)   = false;
h.softValid(stale) = false;
h.lastSlot(stale)  = -1;
end
