function c = pdcpConfig(slPdcpConfig, castType, tReorderingMs, sduType)
%pdcpConfig Resolve SL-PDCP-Config-r16 into the numbers a sidelink PDCP entity uses.
%Spec:   TS 38.331 V16.22.0, SL-PDCP-Config-r16: sl-DiscardTimer-r16 ENUMERATED {ms3, ms10, ms20,
%        ms25, ms30, ms40, ms50, ms60, ms75, ms100, ms150, ms200, ms250, ms300, ms500, ms750,
%        ms1500, infinity}; sl-PDCP-SN-Size-r16 ENUMERATED {len12bits, len18bits};
%        sl-OutOfOrderDelivery ENUMERATED {true}. TS 38.323 V16.8.0: clause 6.3.2 (SN length;
%        NOTE "For NR sidelink communication for groupcast and broadcast, only 12 bits PDCP SN
%        length is used for the sidelink DRBs"), clause 7.2 (Window_Size = 2^[sl-PDCP-SN-Size]-1,
%        exponent read from the rendered page), clause 7.3 ("For NR sidelink communication, the
%        t-Reordering timer is determined by the UE implementation"), clause 6.3.12 (SDU Type).
%Inputs: slPdcpConfig   scalar struct mirroring the ASN.1 leaf, as +cfg/slrbPreconfig stores it:
%                         .sl_DiscardTimer_r16_Present  logical
%                         .sl_DiscardTimer_r16          char label
%                         .sl_PDCP_SN_Size_r16_Present  logical
%                         .sl_PDCP_SN_Size_r16          char label
%                         .sl_OutOfOrderDelivery        logical (the single-valued ENUMERATED
%                                                       {true}: present means true)
%        castType       char, 'broadcast', 'groupcast' or 'unicast' -- selects the PDU format
%                       (clause 6.2.2.4 vs 6.2.2.6/6.2.2.7)
%        tReorderingMs  real, >=0 -- t-Reordering in ms. A receiving-UE choice (clause 7.3), so an
%                       input rather than a config field
%        sduType        integer, 0 (IP) or 1 (Non-IP) -- clause 6.3.12 Table 6.3.12-1. V2X
%                       application messages are Non-IP
%Outputs: c  scalar struct:
%            .castType            char, as given
%            .format              char, 'sl-gc-bc' (Figure 6.2.2.4-1) or 'sl-unicast'
%                                 (Figures 6.2.2.6-1 / 6.2.2.7-1)
%            .snFieldLength       integer, 12 or 18
%            .Window_Size         integer, 2048 or 131072
%            .discardTimerMs      ms, 3..1500, or Inf (configured 'infinity', or absent)
%            .outOfOrderDelivery  logical
%            .t_Reordering        ms
%            .sduType             integer, 0 or 1
%            .securityActive      logical, always false here -- see pdcp.securityProtect
%
%An absent sl-DiscardTimer is read as "no discard timer". The field is Cond Setup, i.e. present
%whenever a sidelink DRB is set up, so absence here means an incomplete config; reading it as
%infinite keeps the entity running but makes PDB discard impossible, and +pdcp/CLAUDE.md
%records why that matters.

DISCARD_MS = [3 10 20 25 30 40 50 60 75 100 150 200 250 300 500 750 1500];
SDU_TYPE_IP = 0;
SDU_TYPE_NON_IP = 1;
SN_GC_BC = 12;          % clause 6.3.2 NOTE

if ~any(strcmp(castType, {'broadcast', 'groupcast', 'unicast'}))
    error('pdcp:pdcpConfig:badCast', 'pdcpConfig: castType must be broadcast, groupcast or unicast');
end
if ~(sduType == SDU_TYPE_IP || sduType == SDU_TYPE_NON_IP)
    error('pdcp:pdcpConfig:badSduType', 'pdcpConfig: SDU Type must be 0 (IP) or 1 (Non-IP), Table 6.3.12-1');
end
if ~(tReorderingMs >= 0)
    error('pdcp:pdcpConfig:badTReordering', 'pdcpConfig: t-Reordering must be >= 0 ms');
end

discardMs = Inf;
if slPdcpConfig.sl_DiscardTimer_r16_Present
    lbl = slPdcpConfig.sl_DiscardTimer_r16;
    if ~strcmp(lbl, 'infinity')
        discardMs = [];
        for k = 1:numel(DISCARD_MS)
            if strcmp(lbl, sprintf('ms%d', DISCARD_MS(k)))
                discardMs = DISCARD_MS(k);
            end
        end
        if isempty(discardMs)
            error('pdcp:pdcpConfig:badDiscard', 'pdcpConfig: "%s" is not an sl-DiscardTimer-r16 value', lbl);
        end
    end
end

isGcBc = ~strcmp(castType, 'unicast');
if slPdcpConfig.sl_PDCP_SN_Size_r16_Present
    switch slPdcpConfig.sl_PDCP_SN_Size_r16
        case 'len12bits', sn = 12;
        case 'len18bits', sn = 18;
        otherwise
            error('pdcp:pdcpConfig:badSnSize', 'pdcpConfig: sl-PDCP-SN-Size-r16 must be len12bits or len18bits');
    end
elseif isGcBc
    sn = SN_GC_BC;
else
    error('pdcp:pdcpConfig:missingSnSize', 'pdcpConfig: a unicast sidelink DRB needs sl-PDCP-SN-Size-r16');
end
if isGcBc && sn ~= SN_GC_BC
    error('pdcp:pdcpConfig:gcBcSnSize', ['pdcpConfig: groupcast/broadcast sidelink DRBs use only 12-bit PDCP SN ' ...
        '(TS 38.323 clause 6.3.2 NOTE), got %d'], sn);
end

if isGcBc
    fmt = 'sl-gc-bc';
else
    fmt = 'sl-unicast';
end
c = struct( ...
    'castType',           castType, ...
    'format',             fmt, ...
    'snFieldLength',      sn, ...
    'Window_Size',        2^(sn - 1), ...
    'discardTimerMs',     discardMs, ...
    'outOfOrderDelivery', logical(slPdcpConfig.sl_OutOfOrderDelivery), ...
    't_Reordering',       tReorderingMs, ...
    'sduType',            sduType, ...
    'securityActive',     false);
end
