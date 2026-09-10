function lc = linkConfig(mcs, LsubCH, scen)
%linkConfig Everything one link-level slot needs, derived from an MCS and an allocation.
%Spec:   none itself; every quantity is resolved through the package that owns it --
%        phy.ts38214.mcsTableSelect, phy.ts38214.tbsDetermine, phy.ts38212.sci2OutputLength.
%Inputs: mcs     integer, 0..31 -- I_MCS
%        LsubCH  integer, >=1 -- sub-channels allocated to the PSSCH
%        scen    a scenario struct from harness.sls.scenarioInit, for the pool geometry. Taken
%                from there rather than re-declared so the link-level and system-level paths
%                cannot drift apart on sub-channel size, symbol count or DM-RS pattern -- which
%                is the whole point of measuring curves in one and consuming them in the other
%Outputs: lc  scalar struct with the carrier/config/mapping structs and sizes the chains need
%
%The link-level and system-level paths MUST agree on this configuration or the BLER table
%measured by one does not describe the other. Deriving both from the same scenario struct is
%what makes that structural rather than a matter of keeping two files in step.

[modScheme, Qm, R] = phy.ts38214.mcsTableSelect(mcs, '', 0);

lc.mcs       = mcs;
lc.LsubCH    = LsubCH;
lc.modScheme = modScheme;
lc.Qm        = Qm;
lc.R         = R;
lc.mu        = scen.mu;
lc.NRB       = LsubCH * scen.subchSizeRb;
lc.startPRB  = 0;
lc.NsymbSlot = 14;
lc.nsf       = 0;
lc.NID       = 12345;                       % N_ID^X, the PSCCH CRC; fixed for a link study
lc.carrier   = struct();

% ---- PSCCH: sl-TimeResourcePSCCH symbols over sl-FreqResourcePSCCH PRBs ----
poolPscch  = struct('sl_DMRS_ScrambleID_r16_Present', false, 'sl_DMRS_ScrambleID_r16', 0);
lc.pscchCfg = phy.ts38211.slPSCCHConfig(poolPscch, struct( ...
    'startPRB', lc.startPRB, 'NRB', scen.pscchPrb, ...
    'symbols', 1:scen.pscchSymbols, 'nsf', lc.nsf, 'NsymbSlot', lc.NsymbSlot));
lc.pscchRE = [phy.ts38211.slPSCCHIndices(lc.carrier, lc.pscchCfg); ...
              phy.ts38211.slPSCCHDMRSIndices(lc.startPRB, scen.pscchPrb, 1:scen.pscchSymbols)];
lc.sci1aBitLen = 32;                        % A for SCI-1A at this pool's field widths

% ---- PSSCH ---------------------------------------------------------------
lc.dmrsSymbols = [3 10];                    % one Table 8.4.1.1.2-1 pattern
lc.ld          = scen.slLengthSymbols;
lc.sci2BitLen  = 35;                        % SCI format 2-A, clause 8.4.1.1

% G^SCI2 from clause 8.4.4. The RE count it needs is the PSSCH region's own size, so it is
% computed from the index list rather than from the nominal allocation.
probeMap = struct('startPRB', lc.startPRB, 'NRB', lc.NRB, 'ld', lc.ld, ...
    'dmrsSymbols', lc.dmrsSymbols, 'Msymb1', 0, 'pscchRE', lc.pscchRE, ...
    'ptrsRE', zeros(0, 2), 'csirsRE', zeros(0, 2));
sumMscSci2 = size(phy.ts38211.slPSSCHIndices(lc.carrier, probeMap), 1);
lc.Gsci2 = phy.ts38212.sci2OutputLength(lc.sci2BitLen, 1.125, R, 1, sumMscSci2, 0);
if mod(lc.Gsci2, 2) ~= 0
    lc.Gsci2 = lc.Gsci2 + 1;                % QPSK needs an even count
end

lc.psschCfg = phy.ts38211.slPSSCHConfig(struct(), struct('NID', lc.NID, ...
    'MbitSCI2', lc.Gsci2, 'modScheme', modScheme, 'nsf', lc.nsf, 'NsymbSlot', lc.NsymbSlot));
lc.mapCfg = probeMap;
lc.mapCfg.Msymb1 = lc.Gsci2 / 2;

nTotal     = size(phy.ts38211.slPSSCHIndices(lc.carrier, lc.mapCfg), 1);
lc.nDataRE = nTotal - lc.mapCfg.Msymb1;
lc.Gslsch  = lc.nDataRE * Qm;

% ---- transport block size, the same clause 8.1.3.2 call the scenario uses --
nReSci1 = scen.pscchSymbols * scen.pscchPrb * 12;
bits = phy.ts38214.tbsDetermine(Qm, R, 1, lc.NRB, scen.slLengthSymbols, ...
    scen.slPsfchPeriod, scen.slPsfchPeriod > 0, 0, [2 3], nReSci1, 2 * lc.NRB);
lc.trblklen = bits;

% Calibrated once here rather than per slot: it depends only on the grid geometry, and
% measuring it inside the sweep would cost an OFDM round trip per SNR point.
lc.noiseScale = harness.lls.noiseScale(lc.NRB * 12, lc.mu, lc.nsf);
end
