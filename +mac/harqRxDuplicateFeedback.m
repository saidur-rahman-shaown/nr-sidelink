function feedback = harqRxDuplicateFeedback(castType, feedbackEnabled)
%harqRxDuplicateFeedback What to answer when a TB already decoded arrives again.
%Spec:   TS 38.321 V16.22.0, clause 5.22.2.2.2. Its feedback block is entered when "the data
%        which the MAC entity attempted to decode was successfully decoded for this TB; **or**
%        if the data for this TB was successfully decoded before" -- so a repeat of a TB the
%        receiver already has still produces a positive acknowledgement. Only DELIVERY is
%        once-only, guarded by "if this is the first successful decoding".
%Inputs: castType         integer, 0..3 -- SCI-2A Cast type indicator, Table 8.4.1.1-1
%        feedbackEnabled  logical -- the SCI's HARQ feedback enabled/disabled indicator
%Outputs: feedback  char -- 'none' or 'ack'
%
%WHY A DUPLICATE MUST STILL BE ACKNOWLEDGED
%--------------------------------------------
%mac.harqRxAssign discards a repeat of an already-completed TB (clause 5.22.2.2.1 NOTE 1a) so
%it is not delivered a second time -- but discarding it must not also silence the receiver. If
%it does, the transmitter sees no PSFCH where it expected one, reads a DTX, and retransmits the
%very TB the receiver already has; and clause 5.22.1.3.3 counts consecutive DTX toward radio
%link failure, so a perfectly healthy link is eventually declared dead.
%
%Measured when this was missed: unicast delivery fell from 200/200 to 160/200 as soon as
%duplicate suppression was added without this rule. The two changes are only correct together.
%
%'none' for broadcast and for feedback-disabled transmissions, matching harqRxProcess. NACK-only
%groupcast also returns 'none': silence IS its positive acknowledgement, so a successfully
%decoded TB -- first time or repeated -- says nothing.

CAST_BROADCAST = 0;
CAST_GROUPCAST_NACK_ONLY = 3;

if ~any(castType == [0 1 2 3])
    error('mac:harqRxDuplicateFeedback:badCastType', 'harqRxDuplicateFeedback: castType must be 0..3, got %s', num2str(castType));
end

if ~feedbackEnabled || castType == CAST_BROADCAST || castType == CAST_GROUPCAST_NACK_ONLY
    feedback = 'none';
else
    feedback = 'ack';
end
end
