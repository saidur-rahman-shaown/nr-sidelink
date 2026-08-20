function t = pqiTable()
%pqiTable TS 23.287 PC5 5QI (PQI) -> {priority, PDB, PER, resourceType} table.
%Spec:   TS 23.287 clause 5.4.4, Table 5.4.4-1 (Standardized PC5 QoS characteristics). This
%        repo carries only the 38.331 RRC ASN.1 locally (asn1/NR-Sidelink-RRC-Rel19.asn1) --
%        23.287 text is not present to extract from, so these rows are transcribed from
%        training-data recall of the standard table, not extracted the way ASN.1 field names
%        were. CROSS-CHECK EVERY ROW AGAINST THE ACTUAL TS 23.287 PDF before treating any PDB
%        or PER value here as bit-exact; that is the single biggest open risk in +cfg/ right
%        now. See +cfg/CLAUDE.md build order note.
%Inputs: none
%Outputs: t  1xN struct array, fields:
%            PQI            positive integer, the PC5 5QI value
%            priority       integer 1..8, SL-Priority as used in SCI-1A
%            PDB_ms         packet delay budget, milliseconds
%            PER            packet error rate target (double, e.g. 1e-4)
%            resourceType   char, 'GBR' | 'Non-GBR'
%            defaultPriority logical -- true for the row +sdap/+app default to when a flow
%                            does not specify one explicitly (exactly one row is true)

rows = { ...
    3,  3, 20,  1e-5, 'GBR',     false; ...   % Platoon control, higher throughput
    55, 6, 100, 1e-1, 'Non-GBR', true;  ...   % Basic CAM-like periodic awareness (default)
    65, 5, 100, 1e-1, 'GBR',     false; ...   % Cooperative collision avoidance / hazard warning
    66, 5, 20,  1e-1, 'GBR',     false; ...   % Sensor sharing, high frequency
    67, 5, 500, 1e-1, 'GBR',     false; ...   % Sensor sharing, lower frequency
    68, 5, 20,  1e-1, 'GBR',     false; ...   % Cooperative lane change, high frequency
    69, 4, 500, 1e-1, 'GBR',     false; ...   % Video sharing
    70, 3, 20,  1e-1, 'GBR',     false; ...   % Cooperative lane change, low frequency
    79, 5, 10,  1e-2, 'Non-GBR', false; ...   % Emergency / safety-critical event
    82, 3, 10,  1e-4, 'GBR',     false; ...   % Discrete automation, low latency
    83, 2, 10,  1e-4, 'GBR',     false; ...   % Discrete automation, low latency, high reliability
    84, 3, 30,  1e-5, 'GBR',     false; ...   % Intelligent transport systems
    85, 2, 5,   1e-5, 'GBR',     false; ...   % Electricity distribution, high voltage
    86, 1, 5,   1e-5, 'GBR',     false; ...   % V2X message, urgent/high priority
    87, 3, 500, 1e-1, 'Non-GBR', false; ...   % Live streaming / video
    88, 4, 500, 1e-1, 'Non-GBR', false; ...   % File transfer / non-urgent bulk
    89, 3, 200, 1e-2, 'Non-GBR', false; ...   % Voice-like / interactive
    91, 2, 3,   1e-5, 'DC-GBR',  false ...    % Remote driving (delay-critical GBR)
};

t = repmat(struct('PQI', 0, 'priority', 0, 'PDB_ms', 0, 'PER', 0, 'resourceType', '', 'defaultPriority', false), 1, size(rows, 1));
for i = 1:size(rows, 1)
    t(i).PQI             = rows{i, 1};
    t(i).priority         = rows{i, 2};
    t(i).PDB_ms           = rows{i, 3};
    t(i).PER              = rows{i, 4};
    t(i).resourceType     = rows{i, 5};
    t(i).defaultPriority  = rows{i, 6};
end
end
