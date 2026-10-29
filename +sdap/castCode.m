function code = castCode(castType)
%castCode Map a cast-type label to the integer code the SDAP rules use.
%Spec:   TS 38.331 V16.22.0, sl-CastType-r16 ENUMERATED {broadcast, groupcast, unicast, spare1}.
%        The integer code is this package's own (0 is reserved for "sl-CastType absent").
%Inputs: castType  char, 'broadcast', 'groupcast' or 'unicast'
%Outputs: code  integer, 1, 2 or 3
%
%Not the SCI-2A cast type indicator (TS 38.212 Table 8.4.1.1-1), which has two groupcast code
%points and orders them differently; +sap/castTypes holds that one.

switch castType
    case 'broadcast', code = 1;
    case 'groupcast', code = 2;
    case 'unicast',   code = 3;
    otherwise
        error('sdap:castCode:badCast', 'castCode: "%s" is not a sl-CastType-r16 value (spare1 is not legal)', castType);
end
end
