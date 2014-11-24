function writeSimpleYAML(s, filePath)
% WRITESIMPLEYAML Converts a simple, entirely scalar struct (which can have
% fields which are themselves structs) in to a YAML file

if ~isstruct(s)
    error('Must be a structure')
end
if ~checkScalar(s)
    error('Structure appears to contain an array. This was not intended to be used to write structure arrays!')
end
if isempty(strfind(filePath, '.yml'))
    filePath=[filePath, '.yml'];
end
fid=fopen(filePath, 'w');
if fid==-1
    error('File could not be opened. Perhaps you do not have permission to write to this directory?')
end

writeYamlEntry(fid,s)
fclose(fid);
end

function allscalar=checkScalar(s)
    if numel(s)>1
        allscalar=0;
    else
        f=fieldnames(s);
        
        allscalar=zeros(numel(f), 1);
        
        for ii=1:numel(f)
            if isnumeric(s.(f{ii}))&& isscalar(s.(f{ii}))
                allscalar(ii)=1;
            elseif ischar(s.(f{ii}))
                allscalar(ii)=1;
            elseif isstruct(s.(f{ii}))
                if numel(s.(f{ii}))==1
                    allscalar(ii)=checkScalar(s.(f{ii}));
                else
                    allscalar(ii)=0;
                end
            end
        end
        allscalar=all(allscalar);
    end
end

function writeYamlEntry(fid,s, indentLevel)
    if nargin<3||isempty(indentLevel)
        indentLevel=0;
    end
    
    f=fieldnames(s);
       
    for ii=1:numel(f)
        
        if indentLevel>0
            fprintf(fid, repmat(' ', 1,4*indentLevel));
        end
        
        if isnumeric(s.(f{ii}))
            fprintf(fid, '%s: %s', f{ii}, num2str(s.(f{ii})));
        elseif ischar(s.(f{ii}))
            fprintf(fid, '%s: %s', f{ii}, s.(f{ii}));
        elseif isstruct(s.(f{ii}))
            fprintf(fid, sprintf('%s:\n', f{ii}));
            writeYamlEntry(fid,s.(f{ii}), indentLevel+1)
        end
        fprintf(fid, '\n');
    end
end
