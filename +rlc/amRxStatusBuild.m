function [rx, pdu] = amRxStatusBuild(rx, grantBytes, nowMs)
%amRxStatusBuild Construct and submit a STATUS PDU if one is triggered and not prohibited.
%Spec:   TS 38.322 V16.3.0, clause 5.3.4:
%          "When STATUS reporting has been triggered, the receiving side of an AM RLC entity
%          shall: if t-StatusProhibit is not running: at the first transmission opportunity
%          indicated by lower layer, construct a STATUS PDU and submit it to lower layer. else:
%          at the first transmission opportunity indicated by lower layer after t-StatusProhibit
%          expires, construct a single STATUS PDU even if status reporting was triggered several
%          times while t-StatusProhibit was running".
%          "When a STATUS PDU has been submitted to lower layer ... start t-StatusProhibit."
%          "When constructing a STATUS PDU, the AM RLC entity shall: for the RLC SDUs with SN
%          such that RX_Next <= SN < RX_Highest_Status that has not been completely received
%          yet, in increasing SN order of RLC SDUs and increasing byte segment order within RLC
%          SDUs, starting with SN = RX_Next up to the point where the resulting STATUS PDU still
%          fits to the total size of RLC PDU(s) indicated by lower layer: [NACK_SN | NACK_SN,
%          SOstart, SOend | NACK_SN, NACK range]; set the ACK_SN to the SN of the next not
%          received RLC SDU which is not indicated as missing in the resulting STATUS PDU."
%        Formats: clause 6.2.2.5; field semantics 6.2.3.10..6.2.3.17.
%Inputs: rx          entity from amRxInit (call rlc.amRxTimer for nowMs first, so an expired
%                    t-StatusProhibit is seen as expired)
%        grantBytes  integer, >=0 -- space available for RLC PDUs at this opportunity
%        nowMs       real, ms -- starts t-StatusProhibit
%Outputs: rx   updated entity (unchanged when no PDU is built)
%         pdu  1 x n octets -- the STATUS PDU, or empty when none is due, it is prohibited, or
%              not even the fixed part fits
%
%ENCODING CHOICES (the clause fixes WHAT is reported, not every encoding of it)
%  * An SDU with nothing received, standing alone          -> NACK_SN.
%  * Two or more consecutive SDUs with nothing received    -> NACK_SN + NACK range (<= 255
%    per set, clause 6.2.3.17's 8 bits; longer runs take several sets).
%  * A partly received SDU -> one NACK_SN + SOstart + SOend per missing byte run, in byte
%    order; SOend = 0xFFFF when the run reaches the SDU's end and that end was never received.
%  * The optional SOstart/SOend on a NACK range set (clause 5.3.4's "if required") is never
%    used: partial SDUs next to a missing run are reported by their own sets.
%
%TRUNCATION NEVER SPLITS AN SDU
%------------------------------
%When the grant runs out, ACK_SN is set to the first SDU whose report did not fit, and NONE of
%that SDU's NACK sets are included. Including some byte runs of SN = s with ACK_SN = s would put
%a NACK at ACK_SN, which clause 6.2.3.10's reading cannot express (everything NACKed must be
%below ACK_SN), and a correct transmitter rejects the report.

SO_END_TO_LAST = 65535;
NACK_RANGE_MAX = 255;       % clause 6.2.3.17, 8-bit field
snLen = rx.cfg.snFieldLength;
M = 2^snLen;
pdu = zeros(1, 0);

if ~rx.statusTriggered
    return;
end
if rx.tStatusProhibitExpiry >= 0 && nowMs < rx.tStatusProhibitExpiry
    return;
end
if grantBytes < rlc.statusPduBytes(false(1, 0), false(1, 0), snLen)
    return;
end

nackSn = zeros(1, 0); soStart = zeros(1, 0); soEnd = zeros(1, 0); nackRange = zeros(1, 0);
ackSn = rx.RX_Highest_Status;
dRhs = rlc.snDiff(rx.RX_Highest_Status, rx.RX_Next, snLen);

s = rx.RX_Next;
while rlc.snDiff(s, rx.RX_Next, snLen) < dRhs
    if any(rx.doneSn == s)
        s = mod(s + 1, M);
        continue;
    end
    % This SDU's NACK set(s).
    eSn = zeros(1, 0); eS0 = zeros(1, 0); eS1 = zeros(1, 0); eR = zeros(1, 0);
    if ~any(rx.buf.sn == s)
        % Nothing received: extend over the run of wholly missing SDUs.
        run = 1;
        while run < NACK_RANGE_MAX
            t = mod(s + run, M);
            if rlc.snDiff(t, rx.RX_Next, snLen) >= dRhs || any(rx.doneSn == t) || any(rx.buf.sn == t)
                break;
            end
            run = run + 1;
        end
        eSn = s; eS0 = -1; eS1 = -1;
        if run == 1
            eR = 0;
        else
            eR = run;
        end
        step = run;
    else
        [g0, g1] = rlc.rxBufGaps(rx.buf, s);
        for g = 1:numel(g0)
            eSn(end + 1) = s;           %#ok<AGROW>
            eS0(end + 1) = g0(g);       %#ok<AGROW>
            if g1(g) < 0
                eS1(end + 1) = SO_END_TO_LAST;  %#ok<AGROW>
            else
                eS1(end + 1) = g1(g);   %#ok<AGROW>
            end
            eR(end + 1) = 0;            %#ok<AGROW>
        end
        step = 1;
    end
    trial = rlc.statusPduBytes([soStart >= 0, eS0 >= 0], [nackRange > 0, eR > 0], snLen);
    if trial > grantBytes
        ackSn = s;
        break;
    end
    nackSn = [nackSn, eSn];             %#ok<AGROW>
    soStart = [soStart, eS0];           %#ok<AGROW>
    soEnd = [soEnd, eS1];               %#ok<AGROW>
    nackRange = [nackRange, eR];        %#ok<AGROW>
    s = mod(s + step, M);
end

pdu = rlc.statusPduPack(ackSn, nackSn, soStart, soEnd, nackRange, snLen);
rx.statusTriggered = false;
rx.tStatusProhibitExpiry = nowMs + rx.cfg.t_StatusProhibit;
end
