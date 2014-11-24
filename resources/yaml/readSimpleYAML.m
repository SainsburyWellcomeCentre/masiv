function s=readSimpleYAML(filePath)
% READSIMPLEYAML Reads in a yaml file, containing no arrays and only
% numerical or string values, in to a structure
 %#ok<*ST2NM>

if isempty(strfind(filePath, '.yml'))
    filePath=[filePath, '.yml'];
end

if ~exist(filePath, 'file')
    error('File %s does not exist', filePath)
end
fid=fopen(filePath, 'r');
if fid==-1
    error('File could not be opened.')
end

s=scanYamlFile(fid);
fclose(fid);
end

function s=scanYamlFile(fid, currentDepth)
    if nargin<2||isempty(currentDepth)
        currentDepth=0;
    end
    while ~feof(fid)
        beginningPos=ftell(fid);
        wholeLine=fgetl(fid);
        l=strsplit(wholeLine, ':');
        if ~isempty(wholeLine)
            nm=l{1};
            val=l{2};
            
            indentLevel=sum(nm==' ')/4;
            nm=strtrim(nm);
            if indentLevel>currentDepth
                error('Indent level jump with unknown cause')
            elseif indentLevel<currentDepth
                fseek(fid, beginningPos, 'bof');
                return
            else
                if isempty(val)
                    %recurse
                    s.(nm)=scanYamlFile(fid, currentDepth+1);
                else
                    if ~isempty(str2num(val))
                        val=str2num(val);
                    else
                        val=strtrim(val);
                    end
                    s.(nm)=val;
                end
            end
        end
    end

end