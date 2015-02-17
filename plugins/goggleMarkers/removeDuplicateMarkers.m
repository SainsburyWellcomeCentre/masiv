function M=removeDuplicateMarkers(M)
%REMOVEDUPLICATEMARKERS 

fprintf('Removing identical duplicates...\n')

f=fieldnames(M);

for ii=1:numel(f)
    if isfield(M.(f{ii}), 'markers') && ~isempty(M.(f{ii}).markers)
    prevSz=numel(M.(f{ii}).markers);
    M.(f{ii}).markers=table2struct(unique(struct2table(M.(f{ii}).markers)));
    newSz=numel(M.(f{ii}).markers);
    if newSz<prevSz
        fprintf('\t %u duplicate entries removed from %s\n', prevSz-newSz, f{ii})
    else
        fprintf('\t No duplicates found in %s\n', f{ii})
    end
    else
        fprintf('\t No markers in field %s\n', f{ii})
    end
end

end



