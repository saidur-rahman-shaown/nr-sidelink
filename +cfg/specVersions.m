function v = specVersions()
%specVersions Frozen spec version strings, the single source clause-cited headers pull from.
%Spec:   TS 38.331 (whole package) -- specVersions.json is the frozen version record itself,
%        not a clause of any one spec.
%Inputs: none
%Outputs: v  scalar struct, fields TS38331, TS38211, TS38212, TS38213, TS38214, TS38215,
%            TS38321, TS38322, TS38323, TS37324, TS24587, TS23287, TS37885, asn1Release
%            (all char row vectors, e.g. v.TS38331 == 'V16.6.0')
here = fileparts(mfilename('fullpath'));
raw  = jsondecode(fileread(fullfile(here, 'specVersions.json')));
v = rmfield(raw, 'x_comment');
end
