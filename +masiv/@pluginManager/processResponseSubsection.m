function [subsectionName,data]=processResponseSubsection(response)
    % masiv.pluginManager.processResponseSubsection
    %
    % Extract data from an API response block in the form: 
    % "SUBECTIONNAME":{"KEY":"VALUE","KEY":VALUE}
    %
    % Private method

    %Get the key (name) of this section
    tok=regexp(response,'"(.*?)"\: *{.*?}','tokens');
    if isempty(tok)
        error('failed to get substring section name')
    end
    subsectionName=tok{1}{1};

    %Get the block within the curly brackets
    block = regexp(response,'"\: *({.*?})','tokens');
    if isempty(block)
        error('failed to get data from sub-section')
    end
    block = block{1}{1};

    tok=regexp(block,'"(.+?)"\: *"(.*?)"','tokens');
    if isempty(tok)
        error('failed to get data from sub-section')
    end

    for ii=1:length(tok)
        data.(tok{ii}{1})=tok{ii}{2};
    end
end
