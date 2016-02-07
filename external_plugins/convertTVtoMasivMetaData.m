function varargout=convertTVtoMasivMetaData(filePath)
    if nargin < 1 || isempty(filePath)
        [f,p]=uigetfile('*.txt', 'Please select the TV Metadata file', gbSetting('defaultDirectory'));
        filePath=fullfile(p,f);
    else
        p=fileparts(filePath);
    end
    m=getMetaDataFromFile(filePath);
    
    yml.VoxelSize.x=1;
    yml.VoxelSize.y=1;
    yml.VoxelSize.z=m.zres*2;
    yml.sampleName=m.SampleID;
    
    outputFile=fullfile(p, [yml.sampleName '_MaSIV'], [yml.sampleName '_Meta']);
    writeSimpleYAML(yml, outputFile)
    if nargout>0
        varargout{1} = yml;
    end
    if nargout>1
        varargout{2} = outputFile;
    end
end

function m=getMetaDataFromFile(metaDataFullPath)
 %Get meta-data from TissueVision Mosaic file
    delimiterInTextFile='\r\n';
    %% Open
    fh=fopen(metaDataFullPath);
    
    %% Read
    txtFileContents=textscan(fh, '%s', 'Delimiter', delimiterInTextFile);
    txtFileContents=txtFileContents{1};
    
    %% Parse
    info=struct;
    for ii=1:length(txtFileContents)
        spl=strsplit(txtFileContents{ii}, ':');
    
        if numel(spl)<2
            error('Invalid name/value pair: %s', txtFileContents{ii})
        elseif numel(spl)>2
            spl{2}=strjoin(spl(2:end), ':');
            spl=spl(1:2);
        end
        nm=strrep(spl{1}, ' ', '');
        val=spl{2};
        valNum=str2double(val);
        if ~isempty(valNum)&&~isnan(valNum)
            val=valNum;
        end
    
        info.(nm)=val;
    end

    fclose(fh); 

    %% Assign
    if isempty(info)||~isstruct(info)
        error('Invalid metadata file')
    else
        m=info;
    end
end