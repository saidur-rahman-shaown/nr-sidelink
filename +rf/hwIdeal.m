function hw = hwIdeal()
%hwIdeal The same structure as rf.hwDefaults with every impairment switched off, for ablation:
%a run with this and a run with rf.hwDefaults differ ONLY by the hardware, so their difference is
%the hardware's impact. Linear PA (saturation 40 dB above the operating point), no IQ imbalance,
%no phase noise (mask 200 dB down), no frequency or timing error, 24-bit DAC/ADC. The noise
%figure is kept: thermal noise is physics, not an impairment to remove.
hw = rf.hwDefaults();
hw.tx.paSatDbm = hw.tx.pOutDbm + 40;
hw.tx.iqAmpDb = 0; hw.tx.iqPhaseDeg = 0; hw.tx.dacBits = Inf;
hw.pn.levelDbcHz = repmat(-200, size(hw.pn.levelDbcHz));
hw.lo.ppm = 0;
hw.sync.timingErrUs = 0;
hw.rx.iqAmpDb = 0; hw.rx.iqPhaseDeg = 0; hw.rx.adcBits = 24;
end
