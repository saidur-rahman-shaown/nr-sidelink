function [rb, viaDefault] = sdapTxMap(rules, pqi, castType)
%sdapTxMap Map an outgoing PC5 QoS flow to its sidelink radio bearer.
%Spec:   TS 37.324 V19.0.0 (local), clause 5.2.3 SL transmission: if there is no stored QoS-flow-to-SLRB mapping rule for the QoS
%        flow, map the SDAP SDU to the default SLRB; otherwise map it to the SLRB the stored rule
%        names. TS 38.331 V16.22.0 supplies the rules (sl-MappedQoS-FlowsList, sl-DefaultRB,
%        sl-CastType) -- see sdap.sdapRules -- and clause 5.8.9.1a.2.2 establishes an SDAP entity
%        "associated with the destination and the cast type of the sidelink DRB".
%Inputs: rules     struct from sdap.sdapRules
%        pqi       integer, 1..255 -- the flow's standardized PQI (TS 23.287), as the V2X layer
%                  hands it down with the packet
%        castType  char, 'broadcast', 'groupcast' or 'unicast'
%Outputs: rb          integer -- index into the SLRB list, or 0 when neither a rule nor a default
%                     applies (the packet cannot be sent; the caller must not invent a bearer)
%          viaDefault  logical -- the default SLRB was used
%
%Rules are matched on cast type as well as PQI. The same PQI legitimately maps to different
%SLRBs for broadcast and for unicast (UM versus AM RLC, different PDCP SN sizes), so a PQI-only
%match would put a unicast packet on a broadcast bearer -- which then goes out on the wrong RLC
%mode and is acknowledged by no one.

CAST_ANY = 0;
PQI_MAX = 255;                % SL-PQI-r16 sl-StandardizedPQI-r16 INTEGER (0..255)
if ~(pqi >= 0 && pqi <= PQI_MAX && mod(pqi, 1) == 0)
    error('sdap:sdapTxMap:badPqi', 'sdapTxMap: PQI must be an integer in 0..255, got %s', num2str(pqi));
end
c = sdap.castCode(castType);
rb = 0;
viaDefault = false;
for k = 1:numel(rules.pqi)
    if rules.pqi(k) == pqi && (rules.cast(k) == c || rules.cast(k) == CAST_ANY)
        rb = rules.rb(k);
        return;
    end
end
if rules.defaultRb(c) ~= 0
    rb = rules.defaultRb(c);
    viaDefault = true;
end
end
