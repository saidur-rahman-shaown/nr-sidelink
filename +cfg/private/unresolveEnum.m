function label = unresolveEnum(kind, value)
%unresolveEnum Resolved MATLAB value -> ASN.1 ENUMERATED label. Exact inverse of resolveEnum.m.
%Spec:   TS 38.331, per-field ENUMERATED value lists -- see resolveEnum.m for clause mapping.
%Inputs: kind   char, enum-kind identifier, must match a case in resolveEnum.m
%        value  the resolved value previously produced by resolveEnum.m for this kind
%Outputs: label  char, the ASN.1 enumerated label
%
%Every case here is the exact inverse of the matching case in resolveEnum.m. Keep the two
%files in lockstep -- this is the "documented once" hyphen/label table's other half.
switch kind

  case 'subcarrierSpacing'
    switch value
      case 15,  label = 'kHz15';
      case 30,  label = 'kHz30';
      case 60,  label = 'kHz60';
      case 120, label = 'kHz120';
      case 240, label = 'kHz240';
      otherwise, error('cfg:unresolveEnum:badValue', 'subcarrierSpacing: unresolvable value %g', value);
    end

  case 'cyclicPrefix'
    switch value
      case 'extended', label = 'extended';
      otherwise, error('cfg:unresolveEnum:badValue', 'cyclicPrefix: unresolvable value "%s"', value);
    end

  case 'sl-LengthSymbols-r16'
    switch value
      case 7,  label = 'sym7';
      case 8,  label = 'sym8';
      case 9,  label = 'sym9';
      case 10, label = 'sym10';
      case 11, label = 'sym11';
      case 12, label = 'sym12';
      case 13, label = 'sym13';
      case 14, label = 'sym14';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-LengthSymbols-r16: unresolvable value %g', value);
    end

  case 'sl-StartSymbol-r16'
    switch value
      case 0, label = 'sym0';
      case 1, label = 'sym1';
      case 2, label = 'sym2';
      case 3, label = 'sym3';
      case 4, label = 'sym4';
      case 5, label = 'sym5';
      case 6, label = 'sym6';
      case 7, label = 'sym7';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-StartSymbol-r16: unresolvable value %g', value);
    end

  case 'sl-SubchannelSize-r16'
    switch value
      case 10,  label = 'n10';
      case 12,  label = 'n12';
      case 15,  label = 'n15';
      case 20,  label = 'n20';
      case 25,  label = 'n25';
      case 50,  label = 'n50';
      case 75,  label = 'n75';
      case 100, label = 'n100';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-SubchannelSize-r16: unresolvable value %g', value);
    end

  case 'sl-Additional-MCS-Table-r16'
    switch value
      case {'qam256', 'qam64LowSE', 'qam256-qam64LowSE'}, label = value;
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-Additional-MCS-Table-r16: unresolvable value "%s"', value);
    end

  case 'sl-TimeWindowSizeCBR-r16'
    switch value
      case {'ms100', 'slot100'}, label = value;
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-TimeWindowSizeCBR-r16: unresolvable value "%s"', value);
    end

  case 'sl-TimeWindowSizeCR-r16'
    switch value
      case {'ms1000', 'slot1000'}, label = value;
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-TimeWindowSizeCR-r16: unresolvable value "%s"', value);
    end

  case 'sl-PreemptionEnable-r16'
    switch value
      case {'enabled', 'pl1', 'pl2', 'pl3', 'pl4', 'pl5', 'pl6', 'pl7', 'pl8'}, label = value;
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-PreemptionEnable-r16: unresolvable value "%s"', value);
    end

  case 'sl-X-Overhead-r16'
    switch value
      case 0, label = 'n0';
      case 3, label = 'n3';
      case 6, label = 'n6';
      case 9, label = 'n9';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-X-Overhead-r16: unresolvable value %g', value);
    end

  case 'sl-PSFCH-Period-r16'
    switch value
      case 0, label = 'sl0';
      case 1, label = 'sl1';
      case 2, label = 'sl2';
      case 4, label = 'sl4';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-PSFCH-Period-r16: unresolvable value %g', value);
    end

  case 'sl-NumMuxCS-Pair-r16'
    switch value
      case 1, label = 'n1';
      case 2, label = 'n2';
      case 3, label = 'n3';
      case 6, label = 'n6';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-NumMuxCS-Pair-r16: unresolvable value %g', value);
    end

  case 'sl-MinTimeGapPSFCH-r16'
    switch value
      case 2, label = 'sl2';
      case 3, label = 'sl3';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-MinTimeGapPSFCH-r16: unresolvable value %g', value);
    end

  case 'sl-PSFCH-CandidateResourceType-r16'
    switch value
      case {'startSubCH', 'allocSubCH'}, label = value;
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-PSFCH-CandidateResourceType-r16: unresolvable value "%s"', value);
    end

  case 'sl-TimeResourcePSCCH-r16'
    switch value
      case 2, label = 'n2';
      case 3, label = 'n3';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-TimeResourcePSCCH-r16: unresolvable value %g', value);
    end

  case 'sl-FreqResourcePSCCH-r16'
    switch value
      case 10, label = 'n10';
      case 12, label = 'n12';
      case 15, label = 'n15';
      case 20, label = 'n20';
      case 25, label = 'n25';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-FreqResourcePSCCH-r16: unresolvable value %g', value);
    end

  case 'sl-Scaling-r16'
    switch value
      case 0.5,  label = 'f0p5';
      case 0.65, label = 'f0p65';
      case 0.8,  label = 'f0p8';
      case 1,    label = 'f1';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-Scaling-r16: unresolvable value %g', value);
    end

  case 'sl-TransRange-r16'
    switch value
      case 20,   label = 'm20';
      case 50,   label = 'm50';
      case 80,   label = 'm80';
      case 100,  label = 'm100';
      case 120,  label = 'm120';
      case 150,  label = 'm150';
      case 180,  label = 'm180';
      case 200,  label = 'm200';
      case 250,  label = 'm250';
      case 300,  label = 'm300';
      case 350,  label = 'm350';
      case 400,  label = 'm400';
      case 450,  label = 'm450';
      case 500,  label = 'm500';
      case 550,  label = 'm550';
      case 600,  label = 'm600';
      case 700,  label = 'm700';
      case 1000, label = 'm1000';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-TransRange-r16: unresolvable value %g', value);
    end

  case 'sl-ZoneLength-r16'
    switch value
      case 5,  label = 'm5';
      case 10, label = 'm10';
      case 20, label = 'm20';
      case 30, label = 'm30';
      case 40, label = 'm40';
      case 50, label = 'm50';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-ZoneLength-r16: unresolvable value %g', value);
    end

  case 'sl-MaxNumPerReserve-r16'
    switch value
      case 2, label = 'n2';
      case 3, label = 'n3';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-MaxNumPerReserve-r16: unresolvable value %g', value);
    end

  case 'sl-SensingWindow-r16'
    switch value
      case 100,  label = 'ms100';
      case 1100, label = 'ms1100';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-SensingWindow-r16: unresolvable value %g', value);
    end

  case 'sl-SelectionWindow-r16'
    switch value
      case 1,  label = 'n1';
      case 5,  label = 'n5';
      case 10, label = 'n10';
      case 20, label = 'n20';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-SelectionWindow-r16: unresolvable value %g', value);
    end

  case 'sl-ResourceReservePeriod1-r16'
    switch value
      case 0,    label = 'ms0';
      case 100,  label = 'ms100';
      case 200,  label = 'ms200';
      case 300,  label = 'ms300';
      case 400,  label = 'ms400';
      case 500,  label = 'ms500';
      case 600,  label = 'ms600';
      case 700,  label = 'ms700';
      case 800,  label = 'ms800';
      case 900,  label = 'ms900';
      case 1000, label = 'ms1000';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-ResourceReservePeriod1-r16: unresolvable value %g', value);
    end

  case 'sl-TxPercentage-r16'
    switch value
      case 20, label = 'p20';
      case 35, label = 'p35';
      case 50, label = 'p50';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-TxPercentage-r16: unresolvable value %g', value);
    end

  case 'sl-MCS-Table-r16'
    switch value
      case {'qam64', 'qam256', 'qam64LowSE'}, label = value;
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-MCS-Table-r16: unresolvable value "%s"', value);
    end

  case 'sl-ProbResourceKeep-r16'
    switch value
      case 0,   label = 'v0';
      case 0.2, label = 'v0dot2';
      case 0.4, label = 'v0dot4';
      case 0.6, label = 'v0dot6';
      case 0.8, label = 'v0dot8';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-ProbResourceKeep-r16: unresolvable value %g', value);
    end

  case 'sl-ReselectAfter-r16'
    switch value
      case 1, label = 'n1';
      case 2, label = 'n2';
      case 3, label = 'n3';
      case 4, label = 'n4';
      case 5, label = 'n5';
      case 6, label = 'n6';
      case 7, label = 'n7';
      case 8, label = 'n8';
      case 9, label = 'n9';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-ReselectAfter-r16: unresolvable value %g', value);
    end

  case 'sl-TypeTxSync-r16'
    switch value
      case {'gnss', 'gnbEnb', 'ue'}, label = value;
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-TypeTxSync-r16: unresolvable value "%s"', value);
    end

  case 'sl-ThresUE-Speed-r16'
    switch value
      case 60,  label = 'kmph60';
      case 80,  label = 'kmph80';
      case 100, label = 'kmph100';
      case 120, label = 'kmph120';
      case 140, label = 'kmph140';
      case 160, label = 'kmph160';
      case 180, label = 'kmph180';
      case 200, label = 'kmph200';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-ThresUE-Speed-r16: unresolvable value %g', value);
    end

  case 'sl-Alpha-r16'
    switch value
      case 0,   label = 'alpha0';
      case 0.4, label = 'alpha04';
      case 0.5, label = 'alpha05';
      case 0.6, label = 'alpha06';
      case 0.7, label = 'alpha07';
      case 0.8, label = 'alpha08';
      case 0.9, label = 'alpha09';
      case 1,   label = 'alpha1';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-Alpha-r16: unresolvable value %g', value);
    end

  case 'FilterCoefficient'
    switch value
      case 0,  label = 'fc0';
      case 1,  label = 'fc1';
      case 2,  label = 'fc2';
      case 3,  label = 'fc3';
      case 4,  label = 'fc4';
      case 5,  label = 'fc5';
      case 6,  label = 'fc6';
      case 7,  label = 'fc7';
      case 8,  label = 'fc8';
      case 9,  label = 'fc9';
      case 11, label = 'fc11';
      case 13, label = 'fc13';
      case 15, label = 'fc15';
      case 17, label = 'fc17';
      case 19, label = 'fc19';
      otherwise, error('cfg:unresolveEnum:badValue', 'FilterCoefficient: unresolvable value %g', value);
    end

  case 'sl-PeriodCG1-r16'
    switch value
      case 100,  label = 'ms100';
      case 200,  label = 'ms200';
      case 300,  label = 'ms300';
      case 400,  label = 'ms400';
      case 500,  label = 'ms500';
      case 600,  label = 'ms600';
      case 700,  label = 'ms700';
      case 800,  label = 'ms800';
      case 900,  label = 'ms900';
      case 1000, label = 'ms1000';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-PeriodCG1-r16: unresolvable value %g', value);
    end

  case 't400-r16'
    switch value
      case 100,  label = 'ms100';
      case 200,  label = 'ms200';
      case 300,  label = 'ms300';
      case 400,  label = 'ms400';
      case 600,  label = 'ms600';
      case 1000, label = 'ms1000';
      case 1500, label = 'ms1500';
      case 2000, label = 'ms2000';
      otherwise, error('cfg:unresolveEnum:badValue', 't400-r16: unresolvable value %g', value);
    end

  case 'sl-MaxNumConsecutiveDTX-r16'
    switch value
      case 1,  label = 'n1';
      case 2,  label = 'n2';
      case 3,  label = 'n3';
      case 4,  label = 'n4';
      case 6,  label = 'n6';
      case 8,  label = 'n8';
      case 16, label = 'n16';
      case 32, label = 'n32';
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-MaxNumConsecutiveDTX-r16: unresolvable value %g', value);
    end

  case 'sl-RS-ForSensing-r16'
    switch value
      case {'pscch', 'pssch'}, label = value;
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-RS-ForSensing-r16: unresolvable value "%s"', value);
    end

  case 'sl-SyncPriority-r16'
    switch value
      case {'gnss', 'gnbEnb'}, label = value;
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-SyncPriority-r16: unresolvable value "%s"', value);
    end

  case 'sl-PTRS-RE-Offset-r16'
    switch value
      case {'offset01', 'offset10', 'offset11'}, label = value;
      otherwise, error('cfg:unresolveEnum:badValue', 'sl-PTRS-RE-Offset-r16: unresolvable value "%s"', value);
    end

  case 'dl-UL-TransmissionPeriodicity'
    switch value
      case 0.5,   label = 'ms0p5';
      case 0.625, label = 'ms0p625';
      case 1,     label = 'ms1';
      case 1.25,  label = 'ms1p25';
      case 2,     label = 'ms2';
      case 2.5,   label = 'ms2p5';
      case 5,     label = 'ms5';
      case 10,    label = 'ms10';
      otherwise, error('cfg:unresolveEnum:badValue', 'dl-UL-TransmissionPeriodicity: unresolvable value %g', value);
    end

  otherwise
    error('cfg:unresolveEnum:badKind', 'unresolveEnum: unknown enum kind "%s"', kind);
end
end
