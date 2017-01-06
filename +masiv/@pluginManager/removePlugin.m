function removePlugin(pluginName,force)
    % Remove an installed plugin
    %
    % masiv.pluginManager.removePlugin
    %
    % function removePlugin(pluginName,force)
    %
    %
    % Purpose
    % Removes an installed plugin. Either the plugin is specified by name or, if nothing is provided,
    % a list given to the user and the user chooses interactively. 
    %
    % 
    % Inputs
    % pluginName - [optional] the name of the plugin to remove. If missing a list if provided
    % force - [optional] false by default. If true, the user must confirm the removal
    %
    %
    %
    % Rob Campbell - Basel 2016   

    if nargin<1
        pluginName =[];
    end
    if nargin<2
        force=false;
    end

    pluginsList=masiv.pluginManager.listExternalPlugins(1);

    fprintf('\nWhich plugin do you want to delete?\n')

    %do not proceed until user enters a valid answer
    while 1
        result = str2num(input('? ','s'));
        if ~isempty(result)
            if result>0 && result<=length(pluginsList)
                break
            end
        end
        fprintf('Please enter one of the above numbers and press return\n')
    end
    toDelete = pluginsList{result};

    if ~force
        fprintf('\nAre you sure you want to DELETE plugin directory %s? [y/n]\n',toDelete)
        %do not proceed until user enters a valid answer
        while 1
            result = input('? ','s');
            if strcmpi(result,'y')
                break
            elseif strcmpi(result,'n')
                fprintf('Not deleting\n')
                return
            end
            fprintf('Please enter y/n and press return\n')
        end
    end

    warning off
    rmpath(toDelete)
    warning on 

    success=rmdir(toDelete,'s');

    if success
        fprintf('Deleted %s\n',toDelete)
    else
        fprintf('FAILED to delete %s\n',toDelete)
    end

end
