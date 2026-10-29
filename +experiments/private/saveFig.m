function file = saveFig(f, outDir, name)
%saveFig Write a figure as a 150 dpi PNG under outDir and close it. Returns the file path.
if ~isfolder(outDir), mkdir(outDir); end
file = fullfile(outDir, [name '.png']);
exportgraphics(f, file, 'Resolution', 150, 'BackgroundColor', 'white');
close(f);
end
