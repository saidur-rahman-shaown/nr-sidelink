function [rsrpW, rsrpDbm, nRe] = slRsrp(grid, dmrsInd, variant)
%slRsrp Sidelink reference signal received power, all three sidelink variants.
%Spec:   TS 38.215 V16.7.0, clause 5.1.22 (PSBCH-RSRP), clause 5.1.23 (PSSCH-RSRP), clause
%        5.1.24 (PSCCH-RSRP). All three share one definition -- "the linear average over the
%        power contributions (in [W]) of the resource elements that carry demodulation reference
%        signals associated with <channel>" -- and differ only in WHICH reference signals are
%        averaged, plus the antenna-port summation that clause 5.1.23 alone specifies.
%Inputs: grid     K x L x P complex array -- the RECEIVED sidelink resource grid, per
%                 +phy/+ts38211/CLAUDE.md's "plain [K x L x P] numeric array, never an object":
%                 K subcarriers (common-resource-block-0-relative), L OFDM symbols, and P =
%                 TRANSMIT DM-RS ANTENNA PORTS. Values are RE amplitudes whose squared magnitude
%                 is power in W, so the caller owns the absolute power calibration; this
%                 function only averages what it is given.
%
%                 *** P IS TRANSMIT PORTS, NOT RECEIVER BRANCHES. *** This distinction changes
%                 the answer and is the highest-value thing to get right at this interface, so
%                 it is stated here rather than left to convention. Plane p of the grid is the
%                 channel estimate for one transmit DM-RS port (1000/1001 for PSSCH, TS 38.211
%                 Table 8.4.1.1.2-2), already separated from the others. Clause 5.1.23's "summed
%                 over the antenna ports" applies to THOSE, which is why this function sums
%                 them. Receiver diversity is governed by an entirely different rule -- every
%                 one of clauses 5.1.22/5.1.23/5.1.24/5.1.25 says the reported value "shall not
%                 be lower than the corresponding [value] of any of the individual receiver
%                 branches", which is a LOWER BOUND relative to the best branch, NOT a sum. So a
%                 UE with N receive antennas must combine its branches BEFORE calling this
%                 function, subject to that floor; passing per-branch planes as P would sum them
%                 and inflate RSRP with the receive-antenna count, silently corrupting every
%                 TS 38.214 clause 8.1.4 RSRP threshold comparison downstream. The spec gives a
%                 bound for branch combining, never a formula, so this package does not perform
%                 it -- see +phy/+ts38215/CLAUDE.md.
%        dmrsInd  N x 2 integer matrix, columns [k l], 0-BASED -- the DM-RS RE locations to
%                 average over, exactly as returned by +phy/+ts38211/'s slPSSCHDMRSIndices /
%                 slPSCCHDMRSIndices / slPSBCHDMRSIndices. Producing them is that package's
%                 job (it owns "what appears on the resource grid"); this function never
%                 derives a location, it only reads the ones it is handed. N>=0; N=0 is the
%                 "absent measurement" case, see nRe.
%        variant  char row vector, one of 'psbch', 'pssch', 'pscch' -- WHICH measurement this
%                 is, stated explicitly and never inferred from the index set. +phy/+ts38215/
%                 CLAUDE.md's standing rule: "Do not conflate the two SL-RSRP variants. [...]
%                 Take the variant as an explicit input; never infer it inside the function."
%                 The label is not decoration -- it selects the antenna-port rule below. Note
%                 what it does NOT do: nothing here verifies that dmrsInd actually came from the
%                 matching +ts38211 generator, so passing PSCCH DM-RS indices to a call
%                 declaring 'pssch' produces a plausible wrong number in silence. That pairing
%                 is the caller's obligation (only the caller knows which channel it decoded),
%                 and it is the single easiest way to misuse this function.
%Outputs: rsrpW    real, >=0, W -- the measurement in the clause's own unit, or NaN when
%                  absent (see nRe). Dynamic range is the caller's calibration; for a receiver
%                  referenced to the antenna connector, realistic values span roughly 1e-15 W
%                  (-120 dBm) to 1e-6 W (-30 dBm).
%         rsrpDbm  real, dBm -- 10*log10(rsrpW) + 30, or NaN when absent. Returned alongside
%                  rsrpW deliberately: the clause defines the quantity in [W], but every
%                  downstream consumer in this tree is dBm-based (+phy/+ts38214/'s
%                  sensingDbRecord takes rsrp in dBm and candidateSet compares it against an
%                  sl-Thres-RSRP-List in dBm), and a silent W-vs-dBm mix-up across that boundary
%                  is precisely the "quietly wrong with no symptom that points back here"
%                  failure this package's CLAUDE.md warns about for the RSRP variants.
%         nRe      nonnegative integer -- the number of resource elements the average was taken
%                  over, PER PORT. nRe=0 means the measurement is ABSENT, not zero: per this
%                  package's interface rule, "a measurement over an empty window is not zero;
%                  it is absent, and the caller must be able to tell". rsrpW/rsrpDbm are NaN in
%                  that case so an absent measurement cannot be arithmetic'd into a real one.
%
%Antenna ports. Clause 5.1.23 is the only one of the three that mentions them: PSSCH-RSRP is
%"the linear average over the power contributions [...] of the resource elements OF THE ANTENNA
%PORT(S) that carry demodulation reference signals associated with PSSCH, SUMMED OVER THE
%ANTENNA PORTS", with "demodulation reference signals transmitted on antenna ports 1000 and
%1001 shall be used [...] if two antenna ports are indicated". So for 'pssch' the average is
%taken per port and the per-port averages are then SUMMED (P=2 with equal per-port power gives
%twice the P=1 result, not the same). Clauses 5.1.22/5.1.24 specify no port summation, so
%'psbch' and 'pscch' require P=1 and are rejected on a multi-port grid rather than guessing
%which rule the caller meant. Ports 1000/1001 share identical DM-RS RE LOCATIONS (see
%slPSSCHDMRSIndices' own header: same CDM group, Delta=0, differing only in the w_f(k') weight),
%which is why one index list correctly serves both planes of the grid.
%
%PSBCH-RSRP has one extra allowance this function serves without special-casing. Clause 5.1.22:
%"For PSBCH-RSRP sidelink secondary synchronization signals IN ADDITION TO demodulation
%reference signals for PSBCH MAY be used", with NOTE 3 making it explicit that "it is up to UE
%implementation to use PSBCH DMRS only or both S-SSS and PSBCH DMRS". Both behaviours are
%conformant. Since this function averages exactly the REs it is handed, a caller wanting the
%S-SSS variant includes the S-SSS REs in dmrsInd (TS 38.211 Table 8.4.3.1-1: l = 3,4 and
%k = 2..128 of the S-SS/PSBCH block) and a caller wanting DM-RS only does not. Clause 5.1.22
%NOTE 1 additionally leaves the RE count itself to UE implementation, so nRe is not spec-pinned
%for the PSBCH variant the way it is for the other two.
if ~ischar(variant) || ~isrow(variant)
    error('ts38215:slRsrp:badVariant', 'slRsrp: variant must be a char row vector, one of ''psbch'', ''pssch'', ''pscch''');
end
if ~any(strcmp(variant, {'psbch', 'pssch', 'pscch'}))
    error('ts38215:slRsrp:badVariant', 'slRsrp: variant must be one of ''psbch'' (clause 5.1.22), ''pssch'' (5.1.23), ''pscch'' (5.1.24), got ''%s''', variant);
end
if ndims(grid) > 3
    error('ts38215:slRsrp:badGrid', 'slRsrp: grid must be a K x L x P array, got %d dimensions', ndims(grid));
end
if isempty(dmrsInd)
    rsrpW = NaN;
    rsrpDbm = NaN;
    nRe = 0;
    return;
end
if size(dmrsInd, 2) ~= 2
    error('ts38215:slRsrp:badIndices', 'slRsrp: dmrsInd must be an N x 2 matrix of [k l] pairs, got %d columns', size(dmrsInd, 2));
end
if any(mod(dmrsInd(:), 1) ~= 0) || any(dmrsInd(:) < 0)
    error('ts38215:slRsrp:badIndices', 'slRsrp: dmrsInd entries must be nonnegative integers (0-based [k l])');
end

[K, L, P] = size(grid);
if strcmp(variant, 'pssch')
    maxPorts = 2;   % clause 5.1.23 / TS 38.211 Table 8.4.1.1.2-2: PSSCH DM-RS ports 1000, 1001
else
    maxPorts = 1;   % clauses 5.1.22/5.1.24 specify no antenna-port summation
end
if P > maxPorts
    error('ts38215:slRsrp:badPorts', 'slRsrp: variant ''%s'' allows at most %d transmit DM-RS antenna port(s), got a grid with P=%d. Clause 5.1.23 (PSSCH) is the only sidelink RSRP defining a port summation; PSCCH DM-RS uses one port and PSBCH/S-SS DM-RS uses one port (TS 38.211 clause 8.4). If P was meant as receiver branches, combine them before calling -- see this function''s header', variant, maxPorts, P);
end

k = dmrsInd(:, 1);
l = dmrsInd(:, 2);
if any(k >= K) || any(l >= L)
    error('ts38215:slRsrp:indexOutOfGrid', 'slRsrp: dmrsInd addresses REs outside the grid (max k=%d, l=%d for a %dx%d grid)', max(k), max(l), K, L);
end

% Clause 5.1.22/5.1.23/5.1.24: linear average of the per-RE power over the DM-RS REs, per port;
% then, for PSSCH only, summed over the antenna ports.
nRe = numel(k);
rsrpW = 0;
for p = 1:P
    portSum = 0;
    for i = 1:nRe
        re = grid(k(i) + 1, l(i) + 1, p);
        portSum = portSum + real(re)^2 + imag(re)^2;   % |re|^2, the RE's power contribution in W
    end
    rsrpW = rsrpW + portSum / nRe;
end
rsrpDbm = 10 * log10(rsrpW) + 30;   % W -> dBm; -Inf when rsrpW is exactly 0 (a silent grid)
end
