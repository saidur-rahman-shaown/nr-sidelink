function pl = pathlossDb(dMetres, fcHz, exponent, refDistM)
%pathlossDb Log-distance path loss. A PLACEHOLDER, not a 3GPP model.
%Spec:   NONE, and this matters. TR 37.885 (the 3GPP V2X evaluation methodology, which carries
%        the Urban/Highway V2V models this should eventually use) has **no local PDF** --
%        +cfg/specVersions.json lists TS37885 among the unverified placeholders. Rather than
%        transcribe a model from recall and let it look authoritative, this is an explicit
%        log-distance placeholder with every parameter exposed. Same discipline
%        +cfg/pqiTable.m applies to its TS 23.287 rows.
%Inputs: dMetres   real array, >=0 -- separation
%        fcHz      real, >0 -- carrier frequency
%        exponent  real, >0 -- path loss exponent. 2 is free space; 2.7 to 4 is typical for
%                  vehicular scenarios with ground reflection and blockage
%        refDistM  real, >0 -- reference distance for the free-space anchor, metres
%Outputs: pl  real array, dB, same size as dMetres
%
%PL(d) = FSPL(refDist) + 10*exponent*log10(d/refDist), with d clamped to refDist from below so
%a co-located pair does not produce infinite gain.
%
%FSPL(d) = 20log10(4*pi*d*f/c). Written from the constants rather than as the folded
%"32.4 + 20log10(f_GHz) + 20log10(d_m)" form, because that form's 32.4 hides a unit choice and
%is the kind of constant that gets copied into the wrong units.
%
%REPLACE THIS BEFORE REPORTING ANY ABSOLUTE RESULT. Relative comparisons -- policy A against
%policy B on the same channel -- are meaningful with a placeholder. A PRR-versus-distance curve
%is not; its shape is this function's shape.

c = 299792458;   % speed of light, m/s

if ~(fcHz > 0), error('chanmodel:pathlossDb:badFc', 'pathlossDb: fcHz must be > 0'); end
if ~(exponent > 0), error('chanmodel:pathlossDb:badExponent', 'pathlossDb: exponent must be > 0'); end
if ~(refDistM > 0), error('chanmodel:pathlossDb:badRef', 'pathlossDb: refDistM must be > 0'); end
if any(dMetres(:) < 0), error('chanmodel:pathlossDb:negativeDistance', 'pathlossDb: distance cannot be negative'); end

fsplRef = 20 * log10(4 * pi * refDistM * fcHz / c);
d       = max(dMetres, refDistM);
pl      = fsplRef + 10 * exponent * log10(d / refDistM);
end
