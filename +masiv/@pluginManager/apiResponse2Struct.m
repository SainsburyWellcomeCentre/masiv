function out=apiResponse2Struct(response,verbose)
    % masiv.pluginManager.apiResponse2Struct
    %
    % out=apiResponse2Struct(response,verbose)
    %
    % Purpose: converts a string containing an API response to a structure
    %
    % Private method
    if nargin<1
        fprintf('Please supply an string corresponding to an API response\n')
        return
    end
    if nargin<2
        verbose=0;
    end


    %First strip out arrays of sub-fields, e.g.:
    %
    % "parents": [
    %    {
    %      "sha": "04c987462e53a66ec72aa9ad0a134b3b240a93e2",
    %      "url": "https://api.github.com/repos/raacampbell/neurTraceB/git/commits/04c987462e53a66ec72aa9ad0a134b3b240a93e2",
    %      "html_url": "https://github.com/raacampbell/neurTraceB/commit/04c987462e53a66ec72aa9ad0a134b3b240a93e2"
    %    }
    %  ]
    %
    %as we don't care about these right now so no need to figure out an elegant way of importing them.
    [~,~,match]=regexp(response,'.*(".*?"\:\[.*?\]).*');
    while ~isempty(match)
        response(match{1}(1):match{1}(2))=[];
        [~,~,match]=regexp(response,'.*(".*?"\:\[.*?\]).*');
    end            

    %Pull out sub-fields that aren't arrays (as we removed those above)
    [~,~,match]=regexp(response,'.*(".*?"\: *{.*?})');
    while ~isempty(match)
        block = response(match{1}(1):match{1}(2));
        response(match{1}(1):match{1}(2))=[];
        [subsectionName,data] = masiv.pluginManager.processResponseSubsection(block);
        [~,~,match]=regexp(response,'.*(".*?"\: *{.*?})');

        %Add to output structure
        out.(subsectionName) = data;
        if verbose
            fprintf('Added sub-section %s\n',subsectionName)
        end
    end

    %Everything that's left should be part of the object root
    tok=regexp(response,'"(.+?)"\: *"(.*?)"','tokens');

    if isempty(tok)
        return
    end

    for ii=1:length(tok)
        if verbose
            fprintf('Attempting to add key %s\n',tok{ii}{1})
        end
        out.(tok{ii}{1})=tok{ii}{2};
    end

end
