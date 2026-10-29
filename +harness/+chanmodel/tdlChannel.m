function ch = tdlChannel(profile, delaySpreadNs, speedKmh, fcHz, sampleRate, seed)
%tdlChannel A TR 38.901 tapped-delay-line fading channel. Toolbox body: nrTDLChannel.
%Spec:   3GPP TR 38.901 clause 7.7.2, Table 7.7.2-4 (TDL-D). **No local PDF** -- Documentations/
%        carries the 38.2xx/38.3xx series only -- so the tap delays and gains come from the 5G
%        Toolbox's own implementation rather than being transcribed from recall, the same
%        resolution harness.chanmodel.pathlossRma applies to RMa.
%Inputs: profile        char -- 'TDL-A'..'TDL-E'. **TDL-D is the LOS one**: its first tap
%                       carries a 13.3 dB Rician K-factor, so it fades far less deeply than the
%                       NLOS profiles. That is the right family for a V2V line-of-sight link and
%                       the wrong one for an obstructed city street
%        delaySpreadNs  real, >0 -- RMS delay spread in nanoseconds. ~100 ns is the usual V2V
%                       figure; it scales all the tap delays together
%        speedKmh       real, >=0 -- the speed that sets the maximum Doppler, f_D = v fc / c.
%                       For V2V pass |v1| + |v2|, NOT the relative speed: the scatterers are
%                       static and each moving end adds its own Doppler, so two cars in convoy
%                       at 60 km/h still see a 120 km/h-equivalent spread on the scattered
%                       paths. Relative speed governs only the LOS path's mean shift. (This
%                       line used to say "relative speed"; corrected when harness.field put two
%                       same-direction vehicles on one link and gave them a frozen channel.)
%        fcHz           real, >0 -- carrier frequency, for the Doppler shift
%        sampleRate     real, >0 -- must match phy.lib.ofdmMod's output rate
%        seed           integer -- so a run reproduces exactly
%Outputs: ch  a configured channel System object. Call it as y = ch(x); call reset(ch) between
%             independent realisations
%
%WHAT THIS ADDS THAT PATH LOSS CANNOT
%--------------------------------------
%harness.chanmodel.pathloss gives the AVERAGE loss at a distance -- deterministic, so every link
%at 300 m behaves identically and a PRR-versus-distance curve has no variance about it. A TDL
%adds the multipath structure: the signal arrives by several paths that add constructively or
%destructively, so the channel varies across FREQUENCY (taps at different delays) and across
%TIME (Doppler). Both matter here:
%
%  * At 5.9 GHz the wavelength is 5.1 cm, so at a 120 km/h Doppler speed the coherence time is about
%    0.64 ms -- roughly ONE 30 kHz slot. The channel a retransmission sees is largely
%    independent of the one the first transmission saw, which is where HARQ diversity gain comes
%    from and which AWGN cannot show at all.
%  * TDL-D's delay spread reaches ~1.25 us at 100 ns RMS, against a 2.34 us cyclic prefix at
%    mu=1. It fits, so there is no inter-symbol interference -- but it is comfortably wider than
%    the ~0.67 MHz coherence bandwidth implies against a 3.6 MHz sub-channel, so the channel is
%    NOT flat across one transmission. That is what makes the DM-RS channel estimator earn its
%    place rather than being a formality.
%
%The consequence for results, now measured rather than asserted: an AWGN PSSCH waterfall spans
%about 1 dB, and this profile at 120 km/h spans 6 to 9, with the 10% point 3 to 3.5 dB further
%right at every MCS. Every curve measured under one is wrong under the other, which is why
%harness.phyabs.blerLookup takes the channel model as a table KEY and raises rather than
%substituting when asked for a combination it was not measured under.
%
%3 to 3.5 dB is a SHALLOW penalty as fading goes, and that is TDL-D doing what it is for: its
%13.3 dB Rician K-factor means the LOS component carries about 95% of the power, so the deep
%fades that cost an NLOS profile 8 to 10 dB never happen. Reading this table as "the fading
%penalty" in general would be wrong -- it is the fading penalty on a clear line of sight.

if ~ischar(profile) || ~any(strcmp(profile, {'TDL-A', 'TDL-B', 'TDL-C', 'TDL-D', 'TDL-E'}))
    error('chanmodel:tdlChannel:badProfile', 'tdlChannel: profile must be one of TDL-A..TDL-E, got ''%s''', mat2str(profile));
end
if ~(delaySpreadNs > 0), error('chanmodel:tdlChannel:badDs', 'tdlChannel: delaySpreadNs must be > 0'); end
if ~(speedKmh >= 0),     error('chanmodel:tdlChannel:badSpeed', 'tdlChannel: speedKmh must be >= 0'); end
if ~(fcHz > 0),          error('chanmodel:tdlChannel:badFc', 'tdlChannel: fcHz must be > 0'); end
if ~(sampleRate > 0),    error('chanmodel:tdlChannel:badFs', 'tdlChannel: sampleRate must be > 0'); end

c = 299792458;
maxDoppler = (speedKmh / 3.6) * fcHz / c;

ch = nrTDLChannel;
ch.DelayProfile         = profile;
ch.DelaySpread          = delaySpreadNs * 1e-9;
ch.MaximumDopplerShift  = maxDoppler;
ch.SampleRate           = sampleRate;
ch.NumTransmitAntennas  = 1;
ch.NumReceiveAntennas   = 1;
ch.Seed                 = seed;
% Normalise so the channel neither adds nor removes average power: the path loss model owns the
% level, this object owns only the SHAPE. Without it the SNR a caller asks for is not the SNR it
% gets, and the error moves with the profile.
ch.NormalizePathGains   = true;
end
