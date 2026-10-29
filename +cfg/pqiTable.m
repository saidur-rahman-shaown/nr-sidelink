function t = pqiTable()
%pqiTable TS 23.287 standardized PQI -> {priority, PDB, PER, resource type, MDBV, averaging window}.
%Spec:   TS 23.287 V19.0.0 clause 5.4.4, Table 5.4.4-1 "Standardized PQI to QoS characteristics
%        mapping" (Documentations/23287-j00 copy.pdf, p. 35). Every row below is transcribed from
%        that table, all ten of it; the table has no other rows.
%
%        NOTE 1 of the table: "GBR and Delay Critical GBR PQIs can only be used for unicast PC5
%        communications." Broadcast and groupcast therefore have exactly five PQIs, 55..59. That is
%        the .unicastOnly column, and cfg.cfgValidate rejects a gc/bc SLRB that maps one of the
%        others.
%        NOTE 3: an application-indicated priority may override the Default Priority Level; that
%        override is the caller's (a flow's own priority), not a different row here.
%
%        An earlier version of this file was transcribed from recall, not from the spec, and was
%        wrong. It had PQI 55 as priority 6 / 100 ms / 1e-1 (the spec: 3 / 10 ms / 1e-4), had no
%        56..59, and carried thirteen rows (3, 65-70, 79, 82-89) that are not in 23.287 at all.
%        Callers that meant "a 100 ms periodic broadcast" moved to 58, "a 20 ms broadcast event" to
%        56, and the 200 ms unicast flow to 23.
%Inputs: none
%Outputs: t  1x10 struct array, fields:
%            PQI                positive integer, 21..91 -- the PQI value
%            priority           integer 1..8 -- Default Priority Level (SL-Priority in SCI-1A;
%                               1 is the highest)
%            PDB_ms             positive integer, 3..500 -- packet delay budget, ms
%            PER                real, 1e-5..1e-1 -- packet error rate
%            resourceType       char, 'GBR' | 'Non-GBR' | 'DC-GBR'
%            unicastOnly        logical -- NOTE 1: true for GBR and DC-GBR
%            maxDataBurstBytes  integer bytes, 2000 for DC-GBR; NaN where the table says N/A
%            averagingWindowMs  integer ms, 2000 for GBR and DC-GBR; NaN where the table says N/A
%            defaultPriority    logical -- true for the row +sdap/+app default to when a flow does
%                               not specify one (exactly one row is true: 58, the periodic
%                               100 ms broadcast)

NA = NaN;
rows = { ...
%   PQI prio PDB  PER    type       MDBV  window      example services (Table 5.4.4-1)
    21, 3,   20,  1e-4, 'GBR',     NA,   2000; ...  % platooning between UEs / UE-RSU, higher automation
    22, 4,   50,  1e-2, 'GBR',     NA,   2000; ...  % sensor sharing, higher automation
    23, 3,   100, 1e-4, 'GBR',     NA,   2000; ...  % information sharing for automated driving, higher automation
    55, 3,   10,  1e-4, 'Non-GBR', NA,   NA;   ...  % cooperative lane change, higher automation
    56, 6,   20,  1e-1, 'Non-GBR', NA,   NA;   ...  % platooning informative exchange, low automation; information sharing with RSU
    57, 5,   25,  1e-1, 'Non-GBR', NA,   NA;   ...  % cooperative lane change, lower automation
    58, 4,   100, 1e-2, 'Non-GBR', NA,   NA;   ...  % sensor information sharing, lower automation
    59, 6,   500, 1e-1, 'Non-GBR', NA,   NA;   ...  % platooning, reporting to an RSU
    90, 3,   10,  1e-4, 'DC-GBR',  2000, 2000; ...  % cooperative collision avoidance; sensor / video sharing, higher automation
    91, 2,   3,   1e-5, 'DC-GBR',  2000, 2000  ...  % emergency trajectory alignment; sensor sharing, higher automation
};
DEFAULT_PQI = 58;

t = repmat(struct('PQI', 0, 'priority', 0, 'PDB_ms', 0, 'PER', 0, 'resourceType', '', ...
    'unicastOnly', false, 'maxDataBurstBytes', NaN, 'averagingWindowMs', NaN, 'defaultPriority', false), 1, size(rows, 1));
for i = 1:size(rows, 1)
    t(i).PQI               = rows{i, 1};
    t(i).priority          = rows{i, 2};
    t(i).PDB_ms            = rows{i, 3};
    t(i).PER               = rows{i, 4};
    t(i).resourceType      = rows{i, 5};
    t(i).unicastOnly       = ~strcmp(rows{i, 5}, 'Non-GBR');      % NOTE 1
    t(i).maxDataBurstBytes = rows{i, 6};
    t(i).averagingWindowMs = rows{i, 7};
    t(i).defaultPriority   = rows{i, 1} == DEFAULT_PQI;
end
end
