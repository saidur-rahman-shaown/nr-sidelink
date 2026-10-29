function k = collisions(r)
%collisions Collision and capture statistics of a field run, per transmission and per receiver.
%Spec:   none -- a harness measurement built from the two logs harness.field.run keeps: the
%        transmit log (who sent which PSSCH, where) and the receive log (which PSCCH each UE
%        decoded, and whether that transmission's TB decoded on its own). Nothing is read from
%        inside a UE.
%Inputs: r  struct from harness.field.run
%Outputs: k  scalar struct:
%          .nTx            PSSCH transmissions in the run
%          .nCollided      transmissions overlapped by another in the same slot on at least one
%                          common sub-channel (a resource collision)
%          .nSameStart     of those, ones sharing the STARTING sub-channel: their PSCCHs sit on
%                          the same PRBs, so a receiver can decode at most one SCI
%          .nConcurrent    transmissions sharing their slot with any other (overlapping or not):
%                          the transmitters cannot hear each other (half duplex)
%          .byUe           N x 3 [transmissions collided concurrent] per transmitting UE
%          .outcome        2 x 4 counts, rows [clean; collided], columns
%                          [tbOk sciOnly missed deaf] over every (INITIAL transmission, other UE)
%                          pair -- see "why initial transmissions only" below:
%                            tbOk     the SCI and the TB decoded (stand-alone, before combining)
%                            sciOnly  the SCI decoded, the TB did not
%                            missed   not even the SCI decoded
%                            deaf     the receiver was transmitting in that slot (half duplex)
%          .capture        C x 3 [sirDb snrDb tbOk] for every collided (initial transmission, listening
%                          receiver) pair: the wanted link's SNR minus the strongest overlapping
%                          interferer's at that receiver (path-loss SNRs at equal power), the
%                          wanted SNR, and the outcome -- the capture effect, as data
%          .events         1 x E struct, each collision: .ms .ues .startSubch .LsubCH
%
%WHY INITIAL TRANSMISSIONS ONLY in .outcome and .capture: a blind retransmission carries RV 2,
%which is mostly parity and rarely decodes on its own even on a strong link -- it exists to be
%COMBINED. Scoring it stand-alone reported half of all clean receptions on 30 dB links as "SCI
%only" (the first version did). RV 0 is self-decodable, so its stand-alone outcome is the
%radio's verdict; what combining adds shows up in the packet-level PRR instead. The collision
%COUNTS (.nCollided etc.) include every transmission.
%
%"CLEAN" IS NOT "INTERFERENCE-FREE AT EVERY RECEIVER" -- it is "no other PSSCH on these
%sub-channels in this slot". Out-of-band leakage between adjacent sub-channels is not modelled by
%the channel (ideal OFDM, one sample clock), so this is the complete in-band definition here.
%
%The SNRs are r.linkSnrDb (path loss only, 10 PRB, t = 0). With static UEs that is the link's
%mean SNR for the whole run; with moving UEs it is the t = 0 value and only indicative.

c = r.c;
N = numel(c.ue.x);
tx = r.txLog;
rxl = r.rxLog;
k = struct('nTx', numel(tx), 'nCollided', 0, 'nSameStart', 0, 'nConcurrent', 0, ...
    'byUe', zeros(N, 3), 'outcome', zeros(2, 4), 'capture', zeros(0, 3), ...
    'events', repmat(struct('ms', 0, 'ues', zeros(1, 0), 'startSubch', zeros(1, 0), 'LsubCH', zeros(1, 0)), 1, 0));
src8 = mod(c.ue.l2Id, 2^8);
seen = false(1, numel(tx));
for a = 1:numel(tx)
    t = tx(a);
    same = find([tx.ms] == t.ms & (1:numel(tx)) ~= a);
    ov = same(arrayfun(@(b) overlaps(t, tx(b)), same));
    k.byUe(t.ue, 1) = k.byUe(t.ue, 1) + 1;
    if ~isempty(same)
        k.nConcurrent = k.nConcurrent + 1;
        k.byUe(t.ue, 3) = k.byUe(t.ue, 3) + 1;
    end
    collided = ~isempty(ov);
    if collided
        k.nCollided = k.nCollided + 1;
        k.byUe(t.ue, 2) = k.byUe(t.ue, 2) + 1;
        if any([tx(ov).startSubch] == t.startSubch), k.nSameStart = k.nSameStart + 1; end
        if ~seen(a)
            grp = [a ov];
            seen(grp) = true;
            k.events(end + 1) = struct('ms', t.ms, 'ues', [tx(grp).ue], ...
                'startSubch', [tx(grp).startSubch], 'LsubCH', [tx(grp).LsubCH]);
        end
    end
    if t.isRetx, continue; end
    sendersHere = [tx([a same]).ue];
    for j = setdiff(1:N, t.ue)
        if any(sendersHere == j)
            o = 4;                                           % deaf
        else
            hit = rxl([rxl.ue] == j & [rxl.ms] == t.ms & [rxl.startSubch] == t.startSubch & ...
                [rxl.sourceID] == src8(t.ue));
            if isempty(hit)
                o = 3;                                       % missed
            elseif any([hit.tbOk])
                o = 1;                                       % tbOk
            else
                o = 2;                                       % sciOnly
            end
        end
        k.outcome(1 + collided, o) = k.outcome(1 + collided, o) + 1;
        if collided && o ~= 4
            interferers = setdiff([tx(ov).ue], j);
            if isempty(interferers), continue; end
            snr = r.linkSnrDb(t.ue, j);
            sir = snr - max(r.linkSnrDb(interferers, j));
            k.capture(end + 1, :) = [sir, snr, double(o == 1)];
        end
    end
end
end

function tf = overlaps(p, q)
tf = p.startSubch < q.startSubch + q.LsubCH && q.startSubch < p.startSubch + p.LsubCH;
end
