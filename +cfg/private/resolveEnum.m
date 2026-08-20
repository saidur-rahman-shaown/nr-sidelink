function value = resolveEnum(kind, label)
%resolveEnum ASN.1 ENUMERATED label (as written in JSON) -> resolved MATLAB value.
%Spec:   TS 38.331, per-field ENUMERATED value lists (each case below cites the field whose
%        clause it encodes; see +cfg/CLAUDE.md build order and the Rel-16 field inventory it
%        was extracted from).
%Inputs: kind   char, one of the enum-kind identifiers used by +cfg/*.m (see cases below)
%        label  char, the ASN.1 enumerated label exactly as it appears in the spec/JSON
%Outputs: value  the resolved value: numeric for enumerations whose labels encode a quantity
%                (e.g. 'n10' -> 10), char for purely categorical enumerations (e.g. 'qam256'),
%                where the label already is the canonical MATLAB-side value.
%
%This is the single documented ASN.1-label <-> resolved-value table (portability.md,
%"documented once"). jsonEncode.m calls unresolveEnum.m, its exact inverse, so every entry
%here has a matching entry there -- keep the two files in lockstep.
switch kind

  case 'subcarrierSpacing'   % 38.331 SubcarrierSpacing, kHz
    switch label
      case 'kHz15',  value = 15;
      case 'kHz30',  value = 30;
      case 'kHz60',  value = 60;
      case 'kHz120', value = 120;
      case 'kHz240', value = 240;
      otherwise, error('cfg:resolveEnum:badLabel', 'subcarrierSpacing: unknown label "%s"', label);
    end

  case 'cyclicPrefix'   % BWP.cyclicPrefix, single-valued OPTIONAL (absence == normal)
    switch label
      case 'extended', value = 'extended';
      otherwise, error('cfg:resolveEnum:badLabel', 'cyclicPrefix: unknown label "%s"', label);
    end

  case 'sl-LengthSymbols-r16'   % symbols
    switch label
      case 'sym7',  value = 7;
      case 'sym8',  value = 8;
      case 'sym9',  value = 9;
      case 'sym10', value = 10;
      case 'sym11', value = 11;
      case 'sym12', value = 12;
      case 'sym13', value = 13;
      case 'sym14', value = 14;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-LengthSymbols-r16: unknown label "%s"', label);
    end

  case 'sl-StartSymbol-r16'   % symbols, 0-based
    switch label
      case 'sym0', value = 0;
      case 'sym1', value = 1;
      case 'sym2', value = 2;
      case 'sym3', value = 3;
      case 'sym4', value = 4;
      case 'sym5', value = 5;
      case 'sym6', value = 6;
      case 'sym7', value = 7;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-StartSymbol-r16: unknown label "%s"', label);
    end

  case 'sl-SubchannelSize-r16'   % PRB
    switch label
      case 'n10',  value = 10;
      case 'n12',  value = 12;
      case 'n15',  value = 15;
      case 'n20',  value = 20;
      case 'n25',  value = 25;
      case 'n50',  value = 50;
      case 'n75',  value = 75;
      case 'n100', value = 100;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-SubchannelSize-r16: unknown label "%s"', label);
    end

  case 'sl-Additional-MCS-Table-r16'   % categorical, pass through
    switch label
      case {'qam256', 'qam64LowSE', 'qam256-qam64LowSE'}, value = label;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-Additional-MCS-Table-r16: unknown label "%s"', label);
    end

  case 'sl-TimeWindowSizeCBR-r16'   % categorical, units differ per label (ms vs slot)
    switch label
      case {'ms100', 'slot100'}, value = label;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-TimeWindowSizeCBR-r16: unknown label "%s"', label);
    end

  case 'sl-TimeWindowSizeCR-r16'
    switch label
      case {'ms1000', 'slot1000'}, value = label;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-TimeWindowSizeCR-r16: unknown label "%s"', label);
    end

  case 'sl-PreemptionEnable-r16'   % categorical
    switch label
      case {'enabled', 'pl1', 'pl2', 'pl3', 'pl4', 'pl5', 'pl6', 'pl7', 'pl8'}, value = label;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-PreemptionEnable-r16: unknown label "%s"', label);
    end

  case 'sl-X-Overhead-r16'
    switch label
      case 'n0', value = 0;
      case 'n3', value = 3;
      case 'n6', value = 6;
      case 'n9', value = 9;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-X-Overhead-r16: unknown label "%s"', label);
    end

  case 'sl-PSFCH-Period-r16'   % slots
    switch label
      case 'sl0', value = 0;
      case 'sl1', value = 1;
      case 'sl2', value = 2;
      case 'sl4', value = 4;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-PSFCH-Period-r16: unknown label "%s"', label);
    end

  case 'sl-NumMuxCS-Pair-r16'
    switch label
      case 'n1', value = 1;
      case 'n2', value = 2;
      case 'n3', value = 3;
      case 'n6', value = 6;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-NumMuxCS-Pair-r16: unknown label "%s"', label);
    end

  case 'sl-MinTimeGapPSFCH-r16'   % slots
    switch label
      case 'sl2', value = 2;
      case 'sl3', value = 3;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-MinTimeGapPSFCH-r16: unknown label "%s"', label);
    end

  case 'sl-PSFCH-CandidateResourceType-r16'   % categorical
    switch label
      case {'startSubCH', 'allocSubCH'}, value = label;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-PSFCH-CandidateResourceType-r16: unknown label "%s"', label);
    end

  case 'sl-TimeResourcePSCCH-r16'   % symbols
    switch label
      case 'n2', value = 2;
      case 'n3', value = 3;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-TimeResourcePSCCH-r16: unknown label "%s"', label);
    end

  case 'sl-FreqResourcePSCCH-r16'   % PRB
    switch label
      case 'n10', value = 10;
      case 'n12', value = 12;
      case 'n15', value = 15;
      case 'n20', value = 20;
      case 'n25', value = 25;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-FreqResourcePSCCH-r16: unknown label "%s"', label);
    end

  case 'sl-Scaling-r16'   % fraction, applied to beta-offset scaling per 38.212
    switch label
      case 'f0p5',  value = 0.5;
      case 'f0p65', value = 0.65;
      case 'f0p8',  value = 0.8;
      case 'f1',    value = 1;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-Scaling-r16: unknown label "%s"', label);
    end

  case 'sl-TransRange-r16'   % metres; spare* are reserved, not selectable
    switch label
      case 'm20',   value = 20;
      case 'm50',   value = 50;
      case 'm80',   value = 80;
      case 'm100',  value = 100;
      case 'm120',  value = 120;
      case 'm150',  value = 150;
      case 'm180',  value = 180;
      case 'm200',  value = 200;
      case 'm250',  value = 250;
      case 'm300',  value = 300;
      case 'm350',  value = 350;
      case 'm400',  value = 400;
      case 'm450',  value = 450;
      case 'm500',  value = 500;
      case 'm550',  value = 550;
      case 'm600',  value = 600;
      case 'm700',  value = 700;
      case 'm1000', value = 1000;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-TransRange-r16: unknown or reserved label "%s"', label);
    end

  case 'sl-ZoneLength-r16'   % metres
    switch label
      case 'm5',  value = 5;
      case 'm10', value = 10;
      case 'm20', value = 20;
      case 'm30', value = 30;
      case 'm40', value = 40;
      case 'm50', value = 50;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-ZoneLength-r16: unknown or reserved label "%s"', label);
    end

  case 'sl-MaxNumPerReserve-r16'
    switch label
      case 'n2', value = 2;
      case 'n3', value = 3;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-MaxNumPerReserve-r16: unknown label "%s"', label);
    end

  case 'sl-SensingWindow-r16'   % ms
    switch label
      case 'ms100',  value = 100;
      case 'ms1100', value = 1100;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-SensingWindow-r16: unknown label "%s"', label);
    end

  case 'sl-SelectionWindow-r16'   % raw enumerated value; numerology scaling (x 2^mu) is a
                                   % downstream (+phy/+ts38214) responsibility, never done here
    switch label
      case 'n1',  value = 1;
      case 'n5',  value = 5;
      case 'n10', value = 10;
      case 'n20', value = 20;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-SelectionWindow-r16: unknown label "%s"', label);
    end

  case 'sl-ResourceReservePeriod1-r16'   % ms
    switch label
      case 'ms0',    value = 0;
      case 'ms100',  value = 100;
      case 'ms200',  value = 200;
      case 'ms300',  value = 300;
      case 'ms400',  value = 400;
      case 'ms500',  value = 500;
      case 'ms600',  value = 600;
      case 'ms700',  value = 700;
      case 'ms800',  value = 800;
      case 'ms900',  value = 900;
      case 'ms1000', value = 1000;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-ResourceReservePeriod1-r16: unknown label "%s"', label);
    end

  case 'sl-TxPercentage-r16'   % integer percent (p20 -> 20, i.e. 20%)
    switch label
      case 'p20', value = 20;
      case 'p35', value = 35;
      case 'p50', value = 50;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-TxPercentage-r16: unknown label "%s"', label);
    end

  case 'sl-MCS-Table-r16'   % categorical
    switch label
      case {'qam64', 'qam256', 'qam64LowSE'}, value = label;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-MCS-Table-r16: unknown label "%s"', label);
    end

  case 'sl-ProbResourceKeep-r16'   % probability, kept as double -- see resourcePool.m header
    switch label
      case 'v0',     value = 0;
      case 'v0dot2', value = 0.2;
      case 'v0dot4', value = 0.4;
      case 'v0dot6', value = 0.6;
      case 'v0dot8', value = 0.8;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-ProbResourceKeep-r16: unknown label "%s"', label);
    end

  case 'sl-ReselectAfter-r16'
    switch label
      case 'n1', value = 1;
      case 'n2', value = 2;
      case 'n3', value = 3;
      case 'n4', value = 4;
      case 'n5', value = 5;
      case 'n6', value = 6;
      case 'n7', value = 7;
      case 'n8', value = 8;
      case 'n9', value = 9;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-ReselectAfter-r16: unknown label "%s"', label);
    end

  case 'sl-TypeTxSync-r16'   % categorical
    switch label
      case {'gnss', 'gnbEnb', 'ue'}, value = label;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-TypeTxSync-r16: unknown label "%s"', label);
    end

  case 'sl-ThresUE-Speed-r16'   % km/h
    switch label
      case 'kmph60',  value = 60;
      case 'kmph80',  value = 80;
      case 'kmph100', value = 100;
      case 'kmph120', value = 120;
      case 'kmph140', value = 140;
      case 'kmph160', value = 160;
      case 'kmph180', value = 180;
      case 'kmph200', value = 200;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-ThresUE-Speed-r16: unknown label "%s"', label);
    end

  case 'sl-Alpha-r16'   % fractional path-loss compensation factor, kept as double
    switch label
      case 'alpha0',  value = 0;
      case 'alpha04', value = 0.4;
      case 'alpha05', value = 0.5;
      case 'alpha06', value = 0.6;
      case 'alpha07', value = 0.7;
      case 'alpha08', value = 0.8;
      case 'alpha09', value = 0.9;
      case 'alpha1',  value = 1;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-Alpha-r16: unknown label "%s"', label);
    end

  case 'FilterCoefficient'
    switch label
      case 'fc0',  value = 0;
      case 'fc1',  value = 1;
      case 'fc2',  value = 2;
      case 'fc3',  value = 3;
      case 'fc4',  value = 4;
      case 'fc5',  value = 5;
      case 'fc6',  value = 6;
      case 'fc7',  value = 7;
      case 'fc8',  value = 8;
      case 'fc9',  value = 9;
      case 'fc11', value = 11;
      case 'fc13', value = 13;
      case 'fc15', value = 15;
      case 'fc17', value = 17;
      case 'fc19', value = 19;
      otherwise, error('cfg:resolveEnum:badLabel', 'FilterCoefficient: unknown or reserved label "%s"', label);
    end

  case 'sl-PeriodCG1-r16'   % ms
    switch label
      case 'ms100',  value = 100;
      case 'ms200',  value = 200;
      case 'ms300',  value = 300;
      case 'ms400',  value = 400;
      case 'ms500',  value = 500;
      case 'ms600',  value = 600;
      case 'ms700',  value = 700;
      case 'ms800',  value = 800;
      case 'ms900',  value = 900;
      case 'ms1000', value = 1000;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-PeriodCG1-r16: unknown or reserved label "%s"', label);
    end

  case 't400-r16'   % ms
    switch label
      case 'ms100',  value = 100;
      case 'ms200',  value = 200;
      case 'ms300',  value = 300;
      case 'ms400',  value = 400;
      case 'ms600',  value = 600;
      case 'ms1000', value = 1000;
      case 'ms1500', value = 1500;
      case 'ms2000', value = 2000;
      otherwise, error('cfg:resolveEnum:badLabel', 't400-r16: unknown label "%s"', label);
    end

  case 'sl-MaxNumConsecutiveDTX-r16'
    switch label
      case 'n1',  value = 1;
      case 'n2',  value = 2;
      case 'n3',  value = 3;
      case 'n4',  value = 4;
      case 'n6',  value = 6;
      case 'n8',  value = 8;
      case 'n16', value = 16;
      case 'n32', value = 32;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-MaxNumConsecutiveDTX-r16: unknown label "%s"', label);
    end

  case 'sl-RS-ForSensing-r16'   % categorical
    switch label
      case {'pscch', 'pssch'}, value = label;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-RS-ForSensing-r16: unknown label "%s"', label);
    end

  case 'sl-SyncPriority-r16'   % categorical
    switch label
      case {'gnss', 'gnbEnb'}, value = label;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-SyncPriority-r16: unknown label "%s"', label);
    end

  case 'sl-PTRS-RE-Offset-r16'   % categorical
    switch label
      case {'offset01', 'offset10', 'offset11'}, value = label;
      otherwise, error('cfg:resolveEnum:badLabel', 'sl-PTRS-RE-Offset-r16: unknown label "%s"', label);
    end

  case 'dl-UL-TransmissionPeriodicity'   % ms (TDD-UL-DL-Pattern)
    switch label
      case 'ms0p5',  value = 0.5;
      case 'ms0p625', value = 0.625;
      case 'ms1',    value = 1;
      case 'ms1p25', value = 1.25;
      case 'ms2',    value = 2;
      case 'ms2p5',  value = 2.5;
      case 'ms5',    value = 5;
      case 'ms10',   value = 10;
      otherwise, error('cfg:resolveEnum:badLabel', 'dl-UL-TransmissionPeriodicity: unknown label "%s"', label);
    end

  otherwise
    error('cfg:resolveEnum:badKind', 'resolveEnum: unknown enum kind "%s"', kind);
end
end
