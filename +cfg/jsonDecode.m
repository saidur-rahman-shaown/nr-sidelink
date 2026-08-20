function raw = jsonDecode(jsonPath)
%jsonDecode Read a sidelink config JSON file into the raw (untyped) struct tree.
%Spec:   -- (jsonIO boundary; see +cfg/CLAUDE.md "jsonIO" module and portability.md)
%Inputs: jsonPath  char, path to a JSON file whose top-level object has a "preconfig" key
%                  (the SidelinkPreconfigNR-r16 content, ASN.1-verbatim hyphenated field
%                  names) and, optionally, an "rrcReconfigSl" key (array of per-link
%                  reconfigurations)
%Outputs: raw  scalar struct as produced by MATLAB's jsondecode(): every JSON key has its
%              hyphens auto-transliterated to underscores by jsondecode() itself (verified
%              behaviour, not assumed -- see the design notes this was checked against).
%              cfg.preconfig(), cfg.bwpConfig(), cfg.resourcePool(), cfg.rrcReconfigSl() turn
%              this into the fixed, typed shape the rest of +cfg/ and every other package use.
%
%This file's only job is the text-to-struct boundary crossing; nothing here inspects or
%resolves ASN.1 semantics (ENUMERATED labels, presence flags, CHOICE tags) -- that is the
%typed builders' job, one call each, driven from loadConfig.m.
txt = fileread(jsonPath);
raw = jsondecode(txt);
end
