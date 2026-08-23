function P = slPowerControl(channel, pCmax, p0, alpha, pathloss, mu, mRB)
%slPowerControl Sidelink power control -- SIMPLIFIED, NOT clause 16.2's real formula.
%Spec:   TS 38.213 V16.17.0, clause 16.2 (S-SSB: 16.2.0, PSSCH: 16.2.1, PSCCH: 16.2.2, PSFCH:
%        16.2.3) and clause 16.2.4 (prioritization of simultaneous SL/UL/E-UTRA transmissions)
%
%Deliberately simplified to "always transmit at P_CMAX" -- a max-power-always policy, not the
%real open-loop formula. Every clause 16.2 formula depends on inputs this project does not yet
%produce: pathloss (clause 7.1.1, a *different* clause), CBR and higher-layer-filtered RSRP (no
%RX measurement pipeline exists yet), and per-occasion M_RB counts (+ts38214/+chan/, not built).
%Clause 16.2.4's prioritization rules additionally read as scheduler decision-logic over
%simultaneous events rather than a pure PHY formula -- a poor fit for a stateless function and
%likely a future +harness/ concern instead.
%
%`p0`, `alpha`, `pathloss`, `mu`, `mRB` are accepted for interface stability with the eventual
%real implementation but are not used by this body -- only `channel` (validated) and `pCmax`
%(returned) matter. Revisit once pathloss and the measurement pipeline exist.
%
%Inputs: channel   char, one of 'S-SSB','PSSCH','PSCCH','PSFCH' -- selects which of clause
%                  16.2.0-16.2.3's formulas would apply in a real implementation
%        pCmax     real scalar, dBm -- P_CMAX, TS 38.101-1 (not resolved by this project;
%                   caller-supplied)
%        p0        real scalar, dBm -- P_O for the selected channel (unused)
%        alpha     real scalar, 0..1 -- fractional pathloss compensation factor (unused)
%        pathloss  real scalar, dB -- PL, TS 38.213 clause 7.1.1 (unused)
%        mu        integer, 0..3 -- SCS numerology (unused)
%        mRB       positive integer -- resource blocks for the transmission occasion (unused)
%Outputs: P  real scalar, dBm -- always equal to pCmax
%#ok<*INUSD>
if ~any(strcmp(channel, {'S-SSB', 'PSSCH', 'PSCCH', 'PSFCH'}))
    error('ts38213:slPowerControl:badChannel', 'slPowerControl: channel must be one of ''S-SSB'',''PSSCH'',''PSCCH'',''PSFCH'', got ''%s''', channel);
end
P = pCmax;
end
