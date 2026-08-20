function saveConfig(out, jsonPath)
%saveConfig Write a resolved config (as returned by cfg.loadConfig()) back to a JSON file.
%Spec:   TS 38.331 clause 6.3.5. Inverse of cfg.loadConfig(): loadConfig(saveConfig(loadConfig(p)))
%        must reproduce the same preconfig/rrcReconfigSl struct trees -- see the round-trip
%        test in +test/+unit/+cfg/test_jsonRoundtrip.m.
%Inputs: out       scalar struct as returned by cfg.loadConfig() (only .preconfig and
%                  .rrcReconfigSl are serialised -- the rest is derived, not source data)
%        jsonPath  char, output file path
%Outputs: none (writes jsonPath)
txt = cfg.jsonEncode(out.preconfig, out.rrcReconfigSl);
fid = fopen(jsonPath, 'w');
if fid < 0
    error('cfg:saveConfig:openFailed', 'could not open "%s" for writing', jsonPath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, txt, 'char');
end
