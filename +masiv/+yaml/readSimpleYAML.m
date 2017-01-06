function s=readSimpleYAML(filePath)
% Read YAML from a file into a structure
%
% function s=readSimpleYAML(filePath)
%
% Purpose
% Reads in a yaml file, containing no arrays and only
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

        %If this is a line composed only of tabs (9) or spaces (32) then we ignore it
        if all(double(wholeLine)==9) || all(double(wholeLine)==32)
            continue
        end
        if ~isempty(wholeLine)
            splitLine=strsplit(wholeLine, ':');
            nm=splitLine{1};
            indentLevel=sum(nm==' ')/4;
            nm=strtrim(nm);
            
            if indentLevel>currentDepth
                error('Indent level jump with unknown cause at line %s', wholeLine)
            elseif indentLevel<currentDepth
                if~exist('s', 'var')&&nargout>0
                    s=[];
                end
                fseek(fid, beginningPos, 'bof');
                return
            end

            if numel(splitLine)==1 && strcmp(nm, '-')
                % It's a sequence
                fseek(fid, beginningPos, 'bof');
                s=yaml2structarray(fid, currentDepth);
            else
                val=splitLine{2};
                if isempty(val)
                    % This is a structure. Recurse the next lines
                    s.(nm)=scanYamlFile(fid, currentDepth+1);
                else
                    % Name-value pair
                    if ~isempty(str2num(val))
                        val=str2num(val);
                    else
                        val=strtrim(val);
                    end
                    %Handle cell array of strings
                    if isstr(val)
                        tok=regexp(val,'{(.*)}','tokens');
                        if ~isempty(tok) 
                            val = strsplit(tok{1}{1},',');
                        end
                    end

                    s.(nm)=val;
                end
            end
        end
    end
end

function s=yaml2structarray(fid, currentDepth)
    s=[];
    oldPos=ftell(fid);
    newL=fgetl(fid);
    while ischar(newL)
        
        if isempty(strfind(newL, '-'))
            fseek(fid, oldPos, 'bof');
            break
        else
            
        end
           
        if isempty(s)
            s=scanYamlFile(fid, currentDepth+1);
        else
            s(end+1)=scanYamlFile(fid, currentDepth+1);
        end
        
        oldPos=ftell(fid);
        newL=fgetl(fid);
    end

end
        
        
        
        
        
        
        
        
        
        
        