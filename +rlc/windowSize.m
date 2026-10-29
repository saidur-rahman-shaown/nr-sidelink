function w = windowSize(mode, snFieldLength)
%windowSize AM_Window_Size or UM_Window_Size for a configured SN length.
%Spec:   TS 38.322 V16.3.0, clause 7.2: "AM_Window_Size = 2048 when a 12 bit SN is used,
%        AM_Window_Size = 131072 when an 18 bit SN is used." / "UM_Window_Size = 32 when a 6
%        bit SN is configured, UM_Window_Size = 2048 when a 12 bit SN is configured."
%        TS 38.331 V16.22.0, clause 9.1.1.5 (STCH): for broadcast and groupcast "UM window size
%        is set to 32", consistent with the 6-bit SN it also fixes there.
%Inputs: mode           char, 'am' or 'um'
%        snFieldLength  integer -- 12 or 18 for 'am'; 6 or 12 for 'um' (clause 6.2.3.3)
%Outputs: w  integer -- the window size in SNs
%
%The four values are written as the table the clause gives, not as 2^(n-1): the pairing of
%lengths to modes is itself normative (there is no 18-bit UM and no 6-bit AM), and a formula
%would happily return a value for either.

AM_WINDOW_SN12 = 2048;      % clause 7.2 a)
AM_WINDOW_SN18 = 131072;    % clause 7.2 a)
UM_WINDOW_SN6  = 32;        % clause 7.2 b)
UM_WINDOW_SN12 = 2048;      % clause 7.2 b)

switch mode
    case 'am'
        switch snFieldLength
            case 12, w = AM_WINDOW_SN12;
            case 18, w = AM_WINDOW_SN18;
            otherwise
                error('rlc:windowSize:badLength', 'windowSize: AM SN length must be 12 or 18, got %s', num2str(snFieldLength));
        end
    case 'um'
        switch snFieldLength
            case 6,  w = UM_WINDOW_SN6;
            case 12, w = UM_WINDOW_SN12;
            otherwise
                error('rlc:windowSize:badLength', 'windowSize: UM SN length must be 6 or 12, got %s', num2str(snFieldLength));
        end
    otherwise
        error('rlc:windowSize:badMode', 'windowSize: mode must be ''am'' or ''um''');
end
end
