function ackNack = harqAckCombine(mode, values)
%harqAckCombine RX-side HARQ-ACK reporting to higher layers from PSFCH reception(s).
%Spec:   TS 38.213 V16.17.0, clause 16.3.1
%Inputs: mode    char, one of:
%          'unicast'           -- SCI format 2-A, Cast type indicator "10": pass the single
%                                 determined value through unchanged
%          'groupcastAckNack'  -- SCI format 2-A, Cast type indicator "01": ACK only if every
%                                 intended receiver's PSFCH reception(s) included at least one
%                                 ACK
%          'groupcastNackOnly' -- SCI format 2-B, or SCI format 2-A with Cast type indicator
%                                 "11": ACK only if no PSFCH was received at all (silence
%                                 implies success; a received PSFCH always signals NACK, per
%                                 Table 16.3-3's lack of an ACK codepoint)
%        values  depends on mode:
%          'unicast':           scalar, 0 or 1 -- the single ACK/NACK value determined from
%                                the PSFCH reception
%          'groupcastAckNack':  logical vector, one entry per intended receiver (M_ID) -- true
%                                if that receiver's PSFCH reception(s) included at least one
%                                ACK (combining multiple occasions per M_ID, if any, is the
%                                caller's job -- this function only combines across M_IDs)
%          'groupcastNackOnly': logical scalar -- true if a PSFCH reception was detected at all
%Outputs: ackNack  integer, 0 (NACK) or 1 (ACK) -- the value reported to higher layers
switch mode
    case 'unicast'
        if ~(values == 0 || values == 1)
            error('ts38213:harqAckCombine:badValue', 'harqAckCombine: unicast value must be 0 or 1, got %s', num2str(values));
        end
        ackNack = double(values);
    case 'groupcastAckNack'
        ackNack = double(all(logical(values(:))));
    case 'groupcastNackOnly'
        if values
            ackNack = 0;
        else
            ackNack = 1;
        end
    otherwise
        error('ts38213:harqAckCombine:badMode', 'harqAckCombine: mode must be ''unicast'', ''groupcastAckNack'', or ''groupcastNackOnly'', got ''%s''', mode);
end
end
