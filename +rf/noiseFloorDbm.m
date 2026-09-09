function n = noiseFloorDbm(bwHz, noiseFigureDb)
%noiseFloorDbm Thermal noise power in a given bandwidth, at the receiver input.
%Spec:   none -- physics, not 3GPP. The noise figure is a receiver property; TS 38.101-4
%        specifies UE reference sensitivity, which is a different (and stricter) statement.
%Inputs: bwHz           real, >0 -- noise bandwidth in Hz
%        noiseFigureDb  real, >=0 -- receiver noise figure in dB
%Outputs: n  real, dBm
%
%N = -174 dBm/Hz + 10log10(BW) + NF. The -174 is kT at 290 K expressed per hertz
%(k = 1.380649e-23 J/K, T = 290 K, 10*log10(kT*1000) = -173.98), a named constant rather than a
%bare literal because a bare -174 in a body is exactly what the no-magic-numbers rule is about.

kTDbmPerHz = 10 * log10(1.380649e-23 * 290 * 1000);   % = -173.98 dBm/Hz at 290 K

if ~(bwHz > 0)
    error('rf:noiseFloorDbm:badBw', 'noiseFloorDbm: bwHz must be > 0, got %s', num2str(bwHz));
end
if ~(noiseFigureDb >= 0)
    error('rf:noiseFloorDbm:badNf', 'noiseFloorDbm: noiseFigureDb must be >= 0, got %s', num2str(noiseFigureDb));
end

n = kTDbmPerHz + 10 * log10(bwHz) + noiseFigureDb;
end
