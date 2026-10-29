function v = pooled(Rrow, fi, field)
%pooled Concatenate one per-flow vector field across the seeds of one sweep point.
v = [];
for k = 1:numel(Rrow)
    v = [v Rrow{k}.flow(fi).(field)]; %#ok<AGROW>
end
end
