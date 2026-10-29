function A = abstractionCheck(r)
%abstractionCheck How well does the system-level SINR formula predict what the waveform decoder did?
%Spec:   none -- a calibration of +harness/+sls against the waveform-level deployment.
%        For every PSSCH transmission k in the run and every UE j that was listening in that slot
%        (not transmitting: half duplex), this recomputes the SLS's SINR exactly as
%        harness.chanmodel.slotSinr would -- path loss at the slot's positions, every other
%        transmission of the slot weighted by its sub-channel overlap (nOverlap / L_interferer),
%        thermal noise over the victim's band -- and the SLS's decode probability from the
%        measured tables (harness.phyabs.pscchBler for control, blerLookup for the first
%        transmission's TB). It sets that prediction against what the waveform receiver actually
%        did: whether it found the PSCCH, and whether the TB decoded on its own (rxLog.tbOk).
%Inputs: r  from harness.deploy.run
%Outputs: A  struct:
%   .pairs  table: k, j, collided, sinrDb (SLS formula), predCtrl, predTb, obsCtrl, obsTb, distM
%   .bins   table per SINR bin and collided flag: n, predicted and observed decode rates
%   .gapDb  SINR shift (dB) that best aligns observed with predicted TB decode: positive means the
%           waveform needs MORE SINR than the formula credits (an impairment the formula omits)
%WHAT THE FORMULA LEAVES OUT, AND THIS MEASURES
%In-band emission (PA, IQ image, phase noise) leaking into non-overlapping sub-channels;
%inter-symbol interference when an arrival is later than the cyclic prefix allows; AGC and ADC
%near-far loss; carrier-frequency offset and timing error; per-link fading realisations instead of
%the table's average. The SLS's table already contains average fading and DM-RS estimation loss.
%
%CAVEAT, STATED: the BLER table was measured at the SLS pool geometry (L_subCH 3, 12 sidelink
%symbols, no PSFCH) and MCS 7; the stack transmits MCS 7 on the stored pool (14 symbols, PSFCH
%in every slot, allocation width per grant). Code rates differ slightly, so a residual offset of
%a fraction of a dB is expected even for a perfect formula.
c = r.c; g = r.g;
plM = harness.chanmodel.pathlossModel(c.radio.plModel, struct('fcHz', c.radio.fcHz, ...
    'losMode', c.radio.losMode, 'hTxM', c.radio.hAntM, 'hRxM', c.radio.hAntM));
tx = r.txLog; dec = r.rxLog;
N = r.drop.N;
subBwHz = g.subchSizeRb * 12 * 15e3 * 2^g.mu;
mw = @(dbm) 10.^(dbm / 10);
% Both predicted curves tabulated once on a fine grid (each table lookup reloads the generated
% table, so per-pair lookups over ~1e5 pairs would take minutes).
sg = -40:0.05:60;
pcC = arrayfun(@(s) 1 - harness.phyabs.pscchBler(7, s), sg);
pc = pcC .* arrayfun(@(s) 1 - harness.phyabs.blerLookup(7, s, 1, 'tdld', 120), sg);
look = @(curve, x) interp1(sg, curve, min(max(x, sg(1)), sg(end)));
rows = zeros(0, 9);
slots = unique([tx.ms]);
for ms = slots
    here = find([tx.ms] == ms);
    pos = harness.deploy.positions(r.drop, ms / 1000, c.field.sizeM);
    busy = false(1, N); busy([tx(here).ue]) = true;
    for k = here
        if tx(k).isRetx, continue; end              % compare against the first-attempt curve only
        lo = tx(k).startSubch; hi = lo + tx(k).LsubCH - 1;
        nMw = mw(rf.noiseFloorDbm(subBwHz * tx(k).LsubCH, c.hw.rx.noiseFigureDb));
        for j = find(~busy)
            d = norm(pos(tx(k).ue, :) - pos(j, :));
            S = mw(c.hw.tx.pOutDbm - harness.chanmodel.pathloss(plM, d));
            I = 0; col = false;
            for q = here
                if q == k, continue; end
                ov = max(0, min(hi, tx(q).startSubch + tx(q).LsubCH - 1) - max(lo, tx(q).startSubch) + 1);
                if ov == 0, continue; end
                col = true;
                dq = norm(pos(tx(q).ue, :) - pos(j, :));
                I = I + mw(c.hw.tx.pOutDbm - harness.chanmodel.pathloss(plM, dq)) * ov / tx(q).LsubCH;
            end
            sinr = 10 * log10(S / (nMw + I));
            pCtrl = look(pcC, sinr);
            pTb = look(pc, sinr);
            m = [dec.ue] == j & [dec.ms] == ms & [dec.startSubch] == tx(k).startSubch;
            obsCtrl = any(m);
            obsTb = obsCtrl && any([dec(m).tbOk]);
            rows(end + 1, :) = [k, j, col, sinr, pCtrl, pTb, obsCtrl, obsTb, d]; %#ok<AGROW>
        end
    end
end
A.pairs = array2table(rows, 'VariableNames', {'k', 'j', 'collided', 'sinrDb', 'predCtrl', 'predTb', ...
    'obsCtrl', 'obsTb', 'distM'});
edges = -10:2:30;
b = zeros(0, 7);
for colF = 0:1
    for e = 1:numel(edges) - 1
        m = rows(:, 3) == colF & rows(:, 4) >= edges(e) & rows(:, 4) < edges(e + 1);
        if nnz(m) < 15, continue; end
        b(end + 1, :) = [colF, edges(e) + 1, nnz(m), mean(rows(m, 6)), mean(rows(m, 8)), ...
            mean(rows(m, 5)), mean(rows(m, 7))]; %#ok<AGROW>
    end
end
A.bins = array2table(b, 'VariableNames', {'collided', 'sinrDb', 'n', 'predTb', 'obsTb', 'predCtrl', 'obsCtrl'});
% Best SINR shift aligning observed to predicted TB decode over all pairs (least squares).
A.curve = struct('sinrDb', sg, 'pTb', pc);
shifts = -10:0.25:10; err = zeros(size(shifts));
for q = 1:numel(shifts)
    p = look(pc, rows(:, 4) - shifts(q));
    err(q) = mean((p - rows(:, 8)).^2);
end
[~, i] = min(err);
A.gapDb = shifts(i);
end
