function hw = hwDefaults()
%hwDefaults Transmitter and receiver hardware impairments for the waveform-level deployment.
%Spec:   none -- implementation. Each value is an ASSUMPTION for a typical 5.9 GHz C-V2X module,
%        stated with its basis so it can be replaced field by field with a real datasheet. The
%        models themselves are Communications Toolbox behavioural blocks (rf.txHardwareInit,
%        rf.rxHardwareInit); RF Blockset circuit-envelope models are far too slow for many UEs in
%        continuous time.
%Outputs: hw  scalar struct:
%  .tx.pOutDbm        average PA OUTPUT power over transmitted samples. The PA drive is calibrated
%                     so this is what leaves the antenna port, compression included (23 dBm,
%                     the power class 3 P_CMAX of this study).
%  .tx.paModel        'Rapp' -- AM/AM saturation of a solid-state PA (the model 3GPP RAN4 used for
%                     NR UE PA evaluations).
%  .tx.paSatDbm       PA saturated output power. 30 dBm puts the 23 dBm average 7 dB below
%                     saturation, against an OFDM peak-to-average of ~9-10 dB: the strongest peaks
%                     compress. This is what produces EVM and in-band/adjacent leakage.
%  .tx.paSmoothness   Rapp p. 2 is a common fit for GaAs/CMOS handset PAs.
%  .tx.iqAmpDb / .tx.iqPhaseDeg   modulator IQ gain and phase imbalance (image rejection ~40 dB).
%  .tx.dacBits        DAC resolution; Inf disables.
%  .pn.levelDbcHz / .pn.offsetHz  oscillator phase-noise mask (both ends use the same synthesiser
%                     class). About -95 dBc/Hz at 100 kHz offset: a typical integrated 6 GHz PLL.
%                     The mask starts at 10 kHz, not 1 kHz: comm.PhaseNoise designs its shaping
%                     filter at setup, and resolving 1 kHz at 30.72 MHz took 14.6 s per object
%                     (two per UE) against 0.9 s from 10 kHz. Phase noise below ~2 kHz rotates a
%                     whole 0.5 ms slot together and is removed by the per-slot DM-RS estimate, so
%                     the decoder cannot tell the difference: in-slot RMS phase is 1.2 deg either way.
%  .lo.ppm            carrier-frequency error, drawn uniformly per UE in [-ppm, +ppm]. TS 38.101-1
%                     requires +/-0.1 ppm relative to the synchronisation reference; between two UEs
%                     the relative error is up to 0.2 ppm (1.18 kHz at 5.9 GHz, 3.9 % of the SCS).
%  .sync.timingErrUs  per-UE timing error, uniform in [-x, +x] us, relative to the common (GNSS)
%                     slot boundary. 0.25 us is a typical GNSS-disciplined sidelink UE.
%  .sync.fftAdvanceSamples  the receiver starts its FFT window this many samples early (inside the
%                     cyclic prefix), the standard way to tolerate early as well as late arrivals.
%                     A signal arriving later than CP - advance causes inter-symbol interference.
%  .rx.noiseFigureDb  receiver noise figure.
%  .rx.iqAmpDb / .rx.iqPhaseDeg   demodulator IQ imbalance.
%  .rx.adcBits        ADC resolution (I and Q each).
%  .rx.agcBackoffDb   the AGC sets the RMS of the AGC symbol this far below ADC full scale,
%                     leaving room for the OFDM peaks. A strong near UE then pushes a weak far one
%                     toward the quantisation floor, which is the near-far effect the AGC symbol
%                     exists for.
hw.tx = struct('pOutDbm', 23, 'paModel', 'Rapp', 'paSatDbm', 30, 'paSmoothness', 2, ...
    'iqAmpDb', 0.1, 'iqPhaseDeg', 0.5, 'dacBits', 12);
hw.pn = struct('levelDbcHz', [-88 -95 -115 -135], 'offsetHz', [1e4 1e5 1e6 1e7]);
hw.lo = struct('ppm', 0.1);
hw.sync = struct('timingErrUs', 0.25, 'fftAdvanceSamples', 18);
hw.rx = struct('noiseFigureDb', 9, 'iqAmpDb', 0.1, 'iqPhaseDeg', 0.5, 'adcBits', 10, ...
    'agcBackoffDb', 12);
end
