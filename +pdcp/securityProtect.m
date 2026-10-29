function out = securityProtect(data, count, cfg, direction)
%securityProtect Integrity protection and ciphering of a PDCP SDU -- an interface-shaped stub.
%Spec:   TS 38.323 V16.8.0, clause 5.8 ("For NR sidelink communication, the ciphering function is
%        activated for sidelink SRBs (except for SL-SRB0) and/or sidelink DRBs for a PC5 unicast
%        link by upper layers") and clause 5.9 (integrity, likewise for a PC5 unicast link); the
%        algorithms themselves are TS 33.536, which has no local PDF and is not built.
%Inputs: data       1 x n octets -- the (header-compressed) PDCP SDU
%        count      integer, 0..2^32-1 -- COUNT, the cipher/integrity input clause 5.2.1 binds
%                   ("perform integrity protection, and ciphering using the TX_NEXT")
%        cfg        struct from pdcp.pdcpConfig; .securityActive selects the branch
%        direction  char, 'protect' (transmitter) or 'verify' (receiver)
%Outputs: out  1 x n octets -- data unchanged when security is not active
%
%THIS IS A PASS-THROUGH, AND THAT IS CORRECT RATHER THAN A SHORTCUT -- FOR BROADCAST/GROUPCAST
%-------------------------------------------------------------------------------------------
%Clauses 5.8/5.9 activate security only for a PC5 UNICAST link, and only once upper layers
%(PC5-S Direct Security Mode, TS 24.587/33.536) have established it. Groupcast and broadcast
%SLRBs are never protected, so for them identity is the specified behaviour. For unicast it is
%the "not yet activated" state, which is legitimate before security mode completes and is the
%only state this tree can reach. The function exists so that adding TS 33.536 later is a body
%change at one call site in each direction, with COUNT already threaded through.
%
%It raises, rather than silently passing data through, if asked to protect with security
%active: a stub that quietly returned plaintext under an "active" flag is exactly the failure
%mode +pdcp/CLAUDE.md asks the test to rule out.

if ~any(strcmp(direction, {'protect', 'verify'}))
    error('pdcp:securityProtect:badDirection', 'securityProtect: direction must be protect or verify');
end
COUNT_LIMIT = 2^32;           % clause 6.3.5, 32-bit COUNT
if ~(count >= 0 && count < COUNT_LIMIT && mod(count, 1) == 0)
    error('pdcp:securityProtect:badCount', 'securityProtect: COUNT is a 32-bit unsigned value (clause 6.3.5)');
end
if cfg.securityActive
    error('pdcp:securityProtect:notBuilt', 'securityProtect: TS 33.536 ciphering/integrity is not built');
end
out = data;
end
