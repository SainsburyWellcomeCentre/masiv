classdef (Abstract) masiv_plugin
    % masiv_plugin
    %
    % This abstract (non-instantiable) class handles the installation and updating of
    % of MaSIV plugins from GitHub. 
    %
    % Rob Campbell - Basel 2016


    properties (Constant)
       defaultBranchName='master' %default branch from which to download plugin
       detailsFname='last_updated_details.mat' %name of file that contains the commit details associated with the plugin
    end




    methods (Static)
        %These are the public (user-facing) methods provided by this abstract class

        function isplugin=isPlugin(fileName)
            % masiv_plugin.isPlugin
            %
            % function isplugin=isPlugin(fileName)
            %
            % Purpose: Return true if an m file is a valid MaSIV plugin.
            %          Valid plugins are subclasses of masivPlugin.
            %          fileName must be in your path or in the current directory.
            %
            % Example:
            % masiv_plugin.isPlugin('myPluginFile.m')
            %
            % 
            % Alex Brown - 2016

            if nargin==0
                help('masiv_plugin.isPlugin')
                return
            end

            [~,className]=fileparts(fileName);
            m=meta.class.fromName(className);
            if length(m)==0
                isplugin=false;
                return
            end
            if ismember('masivPlugin', {m.SuperclassList.Name})
                isplugin=true;
            else
                isplugin=false;
            end

        end %isPlugin


        function varargout=install(GitHubURL,targetDir,branchName)
            % Install MaSIV plugin from GitHub to a given target directory
            %
            % masiv_plugin.install 
            %
            % function install(GitHubURL,targetDir,branch)
            %
            % Purpose: 
            % Install the plugin located at a given GitHub URL to either
            % the current directory or a given target directory. This function
            % creates a folder containing the plugin in targetDir.
            % 
            % Inputs
            % GitHubURL - The URL of a MaSIV plugin Git repository hosted on GitHub.
            %             This may be either the URL in the browser location bar or 
            %             the Git respository HTTPS URL on the reposotory's web page.
            % targetDir - An absolute or relative path specifying where the plugin is 
            %             to be installed. If empty or missing, the plugin is installed 
            %             in the current directory.
            % branchName - [optional] By default the function pulls in the plugin 
            %              from the branch named "master". Supply this input argument 
            %              to specify a different branch.
            %              
            % 
            %
            % Examples
            %   masiv_plugin.install('https://github.com/userName/repoName')
            %   masiv_plugin.install('https://github.com/userName/repoName.git')
            %   masiv_plugin.install('https://github.com/userName/repoName',[],'devel')
            %   masiv_plugin.install('https://github.com/userName/repoName','/path/to/stuff/')
            %            
            %
            % Rob Campbell - Basel 2016

            if nargin==0
                help('masiv_plugin.install')
                return
            end

            if nargin<2 | isempty(targetDir)
                targetDir=pwd;
            end

            if nargin<3 | isempty(branchName)
                branchName=masiv_plugin.defaultBranchName;
            end

            %This is where we will attempt to the install the plugin. Do not proceed if the directory already exists
            repoName = masiv_plugin.getRepoName(GitHubURL);
            targetLocation = fullfile(targetDir,repoName);
            if exist(targetLocation,'dir')
                fprintf(['\n A plugin directory already exists at %s\n',...
                    ' You should either:\n    a) Delete this and try again.\n  or\n    b) Use masiv_plugin.update to update it.\n\n'],targetLocation)
                return
            end

            unzippedDir = masiv_plugin.getZip(GitHubURL,branchName);
            if isempty(unzippedDir)
                return
            end

            %Now we query GitHub using the GitHub API in order to log the time this commit was made and the commit's SHA hash
            pluginDetails=masiv_plugin.getLastCommitDetails(GitHubURL,branchName);

            fprintf('Plugin last updated by %s at %s on %s\n', ...
                pluginDetails.author.name, pluginDetails.lastCommit.time, pluginDetails.lastCommit.date) 

            %Save this structure in the unpacked zip directory
            save(fullfile(unzippedDir,masiv_plugin.detailsFname),'pluginDetails')


            %Now we move the directory to the target directory and rename it to the repository name
            fprintf('Attempting to install repository "%s" in directory "%s"\n', repoName, targetLocation)
            movefile(unzippedDir,targetLocation)

            if nargout>0
                varargout{1}=details;
            end

        end %install


        function update(pathToPluginDir)  
            % Check whether MaSIV plugin is up to date and update if not
            %
            % masiv_plugin.update
            %
            % function update(pathToPluginDir)
            %
            % Purpose: 
            % Update an existing plugin located at pathToPluginDir.
            % 
            % Inputs
            % pathToPluginDir - An absolute or relative path specifying where the plugin
            %                   to be updated is installed.
            % 
            %
            % Examples
            %   masiv_plugin.update('/path/to/plugin/')
            %            
            %
            % Rob Campbell - Basel 2016

            detailsFname = masiv_plugin.getDetailsFname(pathToPluginDir);
            if isempty(detailsFname)
                return
            else
                load(detailsFname)
            end


            %Read the Web page and find the sha of the last commit 
            response=urlread(pluginDetails.repositoryURL);
            tok=regexp(response,'<a class="commit-tease-sha" href="(.+?)" data-pjax>','tokens');
            if isempty(tok)
                error('Failed to get commit SHA string from %s\n',pluginDetails.repositoryURL);
            end
            lastSHA = regexprep(tok{1}{1},'/.*/','');
            if strcmp(pluginDetails.sha,lastSHA)
                fprintf('Plugin "%s" is up to date.\n',pluginDetails.repoName)
                return
            end

            %If the commit does not match, then it's possible the repository was indeed updated, but
            %the last commit was to a different branch and is masking the update. We therefore need
            %to generate an API query to get the details of the last commit on the current branch.
            fprintf('Checking if plugin %s is up to date on branch %s\n', pluginDetails.repoName, pluginDetails.branchName)
            lastCommit=masiv_plugin.getLastCommitDetails(pluginDetails.repositoryURL,pluginDetails.branchName);
            if strcmp(lastCommit.sha,pluginDetails.sha)
                fprintf('Plugin "%s" is up to date on branch "%s".\n',pluginDetails.repoName,pluginDetails.branchName)
                return
            end

            %If we're here, the plugin is not up to date
            fprintf('Found an update for plugin "%s". New update is from %s at %s\n', ...
                pluginDetails.repoName,pluginDetails.lastCommit.date,pluginDetails.lastCommit.time)


            %get the zip file for this plugin and this branch using values previously stored in the plugin folder
            unzippedDir = masiv_plugin.getZip(pluginDetails.repositoryURL,pluginDetails.branchName);
            if isempty(unzippedDir)
                return
            end

            %Save the new commit details to this folder
            pluginDetails=lastCommit;
            save(fullfile(unzippedDir,masiv_plugin.detailsFname),'pluginDetails')

            %it should now be safe to replace the existing plugin directory
            rmdir(pathToPluginDir,'s')
            movefile(unzippedDir,pathToPluginDir)

            fprintf('Plugin "%s" updated\n', pluginDetails.repoName)

        end %update


        function changeBranch(pathToPluginDir,newBranchName)  
            % Replace an existing plugin with a version from a different Git branch
            %
            % masiv_plugin.changeBranch
            %
            % function changeBranch(pathToPluginDir,newBranchName)
            %
            % Purpose: 
            % Replace an existing plugin with a version from a different Git branch.
            %
            % 
            % Inputs
            % pathToPluginDir - An absolute or relative path specifying where the plugin
            %                   to be updated is installed.
            % newBranchName   - A string defining the name of the branch to which we will switch.
            %
            % Examples
            %   masiv_plugin.changeBranch('/path/to/plugin/','devel')
            %            
            %
            % Rob Campbell - Basel 2016

            if nargin==0
                help('masiv_plugin.changeBranch')
                return
            end

            detailsFname = masiv_plugin.getDetailsFname(pathToPluginDir);
            if isempty(detailsFname)
                return
            else
                load(detailsFname)
            end

            %Bail out if this branch does not exist on the server            
            if ~masiv_plugin.doesBranchExistOnGitHub(pluginDetails.repositoryURL,newBranchName)
                fprintf('There is no branch named "%s" at %s\n', newBranchName, pluginDetails.repositoryURL)
                return
            end


            %Bail out if the plugin is already using this branch
            if strcmp(pluginDetails.branchName,newBranchName)
                fprintf('Plugin "%s" is already from branch "%s"\n',....
                    pluginDetails.repoName, pluginDetails.branchName)
                return
            end


            %get the zip file for this plugin and this branch using values previously stored in the plugin folder
            unzippedDir = masiv_plugin.getZip(pluginDetails.repositoryURL,newBranchName);
            if isempty(unzippedDir)
                return
            end            

            %Get the details for this commit from the desired branch
            pluginDetails=masiv_plugin.getLastCommitDetails(pluginDetails.repositoryURL,newBranchName);


            %Save the new commit details to the unzipped folder
            save(fullfile(unzippedDir,masiv_plugin.detailsFname),'pluginDetails')

            %it should now be safe to replace the existing plugin directory
            rmdir(pathToPluginDir,'s')
            movefile(unzippedDir,pathToPluginDir)

            fprintf('Plugin "%s" is switched to branch "%s"\n', pluginDetails.repoName,newBranchName)

        end %changeBranch
 

        function varargout=info(pathToPluginDir)  
            % Display info about plugin in a given directory
            %
            % masiv_plugin.info
            %
            % function info=info(pathToPluginDir)
            %
            % Purpose: 
            % Display information about a plugin to screen and optionally return as a structure.
            % 
            %
            % Inputs
            % pathToPluginDir - An absolute or relative path specifying where the plugin
            %                   to be updated is installed.
            %
            % Outputs
            % info - optional structure containing information about the plugin.
            %
            %
            % Examples
            %   masiv_plugin.info('/path/to/plugin/')
            %            
            %
            % Rob Campbell - Basel 2016

            if nargin==0
                help('masiv_plugin.info')
                return
            end

            detailsFname = masiv_plugin.getDetailsFname(pathToPluginDir);
            if isempty(detailsFname)
                return
            else
                load(detailsFname)
            end

            fprintf(['\nRepo name:\t%s\n',...
                'Branch name:\t%s\n',...
                'Repo URL:\t%s\n',...
                'Last commiter:\t%s\n',...
                'Last updated:\t%s at %s\n\n'],...
                pluginDetails.repoName,...
                pluginDetails.branchName,...
                pluginDetails.repositoryURL,...
                pluginDetails.committer.name,...
                pluginDetails.lastCommit.date,pluginDetails.lastCommit.time)



            if nargout>0
                varargout{1}=pluginDetails;
            end

        end %info

        function [pluginDirs,installedFromGitHub]=getPluginDirs(pathToSearch)
            % Recursively search for all directories that contain at least one MaSIV plugin
            %
            % masiv_plugingetPluginDirs
            %
            % function [pluginDirs,installedFromGitHub,dirsToAddToPath]=getPluginDirs(pathToSearch)
            %
            % Purpose
            % As a rule, each plugin (or tightly associated group of plugins) resides in its own directory. 
            % This function recursively searches sub-directories within "pathToSearch" for directories
            % containing MaSIV plugins. 
            %
            % 
            % Inputs
            % pathToSearch - [optional] An absolute or relative path specifying where the plugin
            %                to be updated is installed. If missing, we search from the current directory.
            %
            %
            % Outputs
            % pluginDirs          -  a cell array of paths to plugins
            % installedFromGitHub -  a vector defining whether each path contains plugins that were installed
            %                        from GitHub and so can be updated by masiv_plugin. 
            %
            %
            % Rob Campbell - Basel 2016   

            if nargin<1
                pathToSearch = pwd;
            end

            P=strsplit(genpath(pathToSearch),':'); 
         
            %Loop through P and search for files that are valid MaSIV plugins. Valid plugins are
            %subclasses of masivPlugin
            CWD=pwd; %Because we will have to change to each directory as we search

            pluginDirs={};
            for ii=1:length(P)
                if isempty(P{ii})
                    continue
                end

                mFiles=dir(fullfile(P{ii},'*.m'));

                %fprintf('Looking for plugins in %s\n',P{ii})
                cd(P{ii})

                for m=1:length(mFiles) %Loop through all M files in this directory
                    thisFile = fullfile(P{ii}, mFiles(m).name);
                    if masiv_plugin.isPlugin(thisFile)
                        pluginDirs{length(pluginDirs)+1}=P{ii};

                        if exist(fullfile(P{ii},masiv_plugin.detailsFname),'file')
                            installedFromGitHub(length(pluginDirs))=1;
                        else
                            installedFromGitHub(length(pluginDirs))=0;
                        end

                        break
                    end
                end
             
            end
            cd(CWD)

        end %getPluginDirs

        function  abs_path = absolutepath( rel_path, act_path, throwErrorIfFileNotExist )
            % returns the absolute path relative to a given startpath.
            %
            %   The startpath is optional, if omitted the current dir is used instead.
            %   Both argument must be strings.
            %
            %   Syntax:
            %      abs_path = ABSOLUTEPATH( rel_path, start_path )
            %
            %   Parameters:
            %      rel_path           - Relative path
            %      start_path         - Start for relative path  (optional, default = current dir)
            %
            %   Examples:
            %      absolutepath( '.\data\matlab'        , 'C:\local' ) = 'c:\local\data\matlab\'
            %      absolutepath( 'A:\MyProject\'        , 'C:\local' ) = 'a:\myproject\'
            %
            %      absolutepath( '.\data\matlab'        , cd         ) is the same as
            %      absolutepath( '.\data\matlab'                     )
            %
            %   Jochen Lenz

            % 2nd parameter is optional:
            if nargin < 3
                throwErrorIfFileNotExist = true;
                if  nargin < 2
                    act_path = pwd;
                end
            end

            %build absolute path
            file = java.io.File([act_path filesep rel_path]);
            abs_path = char(file.getCanonicalPath());

            %check that file exists
            if throwErrorIfFileNotExist && ~exist(abs_path, 'file')
                throw(MException('absolutepath:fileNotExist', 'The path %s or file %s doesn''t exist', abs_path, abs_path(1:end-1)));
            end
        end %absolutepath
        
    end % static methods




    methods (Access=protected, Static)
        %These are the private (invisible to the user) methods provided by this abstract class

        function API=URL2API(url)
            % masiv_plugin.URL2API
            %
            % Convert the WWW URL or the Git URL to the base URL of an API call

            API = regexprep(url,'\.git$','');
            API = regexprep(API,'//github.com','//api.github.com/repos');
        end %API


        function zipUrl=getZipURL(url,branchName)
            % masiv_plugin.getZipURL
            %
            % Convert the WWW URL or the Git URL to the url of the zip file containing the archive of the latest master branch commit
            if nargin<2
                branchName=masiv_plugin.defaultBranchName;
            end
            zipUrl = regexprep(url,'\.git$', '');
            zipUrl = [zipUrl,'/archive/',branchName,'.zip'];
        end %getZipURL


        function repoName=getRepoName(url)
            % masiv_plugin.getRepoName
            %
            % Get repo name from the GitHub URL
            tok=regexp(url,'.*/(.+?)(?:\.git)?$', 'tokens');
            if isempty(tok)
                error('Failed to get repository name from url: %s', url)
            end

            repoName = tok{1}{1};

        end %getRepoName


        function unzippedDir = getZip(GitHubURL,branchName)
            % masiv_plugin.getZip
            %
            %Attempt to download the last commit as a ZIP file 
            %This doesn't involve an API call, so we do it first in case it fails because the number of API calls
            %from a given IP address are limited. See protected method "masiv_plugin.checkGitHubLimit" for details.

            zipURL = masiv_plugin.getZipURL(GitHubURL,branchName);
            zipFname = sprintf('masiv_plugin_%s.zip',masiv_plugin.getRepoName(GitHubURL)); %Temporary location of the zip file (should work on Windows too)
            tmpDir = '/tmp';
            zipFname = fullfile(tmpDir,zipFname);

            try 
                websave(zipFname,zipURL);
            catch
                fprintf('\nFAILED to download plugin ZIP file from %s.\nCheck the URL you supplied and try again\n\n', zipURL);
                unzippedDir=[];
                return
            end

            %Now unpack the zip file in the temporary directory
            unzipFileList=unzip(zipFname,tmpDir);
            delete(zipFname)

            %The name of the unzipped directory
            tok=regexp(unzipFileList{1},['(.*?',filesep,masiv_plugin.getRepoName(GitHubURL),'-.+?',filesep,')'],'tokens');
            if isempty(tok)
                error('Failed to get zip file save location from zipfile list. Something stupid went wrong with install!')
            end

            unzippedDir = tok{1}{1};

            %Check that this folder indeed exists (super-paranoid here)
            if ~exist(unzippedDir,'dir')
                error('Expected to find the plugin unzipped at %s but it is not there\n', unzippedDir)
            end

        end %getZip


        function detailsFname = getDetailsFname(pathToPluginDir)
            % masiv_plugin.detailsFname
            % 
            % Get the path to a plugin's details file. This file
            % contains information such as the name of the branch,
            % the commit sha, the last update time, etc

            if ~exist(pathToPluginDir,'dir')
                fprintf('No directory found at %s\n',pathToPluginDir)
                return
            end

            detailsFname = fullfile(pathToPluginDir,masiv_plugin.detailsFname);

            if ~exist(detailsFname,'file')
                fprintf('\n Could not find a "%s" file in directory "%s".\n Please install plugin with "masiv_plugin.install"\n\n',...
                    masiv_plugin.detailsFname,pathToPluginDir)
                detailsFname=[];
                return
            end

        end %getDetailsFname



        function exists=doesBranchExistOnGitHub(pluginURL,branchName)
            % masiv_plugin.doesBranchExistOnGitHub
            %
            % function exists=doesBranchExistOnGitHub(pluginURL,branchName)
            %
            % Purpose: return true if branch "branchName" exists at repository "pluginURL"
            %
            url = regexprep(pluginURL,'\.git$','');
            url = [url,'/commits/',branchName];

            try
                reponse=urlread(url);
                exists=true;
            catch
                exists=false;
            end

        end %doesBranchExistOnGitHub


        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
        % API-related functions
        function out=getLastCommitLocation(url,branchName)
            % masiv_plugin.getLastCommitLocation
            % out=getLastCommitLocation(url,branchName)
            %
            % Purpose: Return the location details (url,sha,ref) of the last commit to the main branch ('master' by default)
            %          of most interest is out.object.url, which is the API call that returns all the details of the
            %          last commit.

            if nargin<2
                branchName=masiv_plugin.defaultBranchName;
            end

            api_call = [masiv_plugin.URL2API(url),'/git/refs/heads/',branchName];
            response = masiv_plugin.executeAPIcall(api_call);
            out = masiv_plugin.apiResponse2Struct(response);
        end %getLastCommitLocation


        function out=getLastCommitDetails(url,branchName)
            % masiv_plugin.getLastCommitDetails
            % out=getLastCommitDetails(url,branchName)
            %
            % Purpose: Return all the details on the last commit. e.g. who made the commit, when it was made, the commit sha, etc.

            if nargin<1
                fprintf('Please supply a GitHub URL\n')
                return
            end
            if nargin<2
                branchName=masiv_plugin.defaultBranchName;
            end

            lastCommit=masiv_plugin.getLastCommitLocation(url,branchName);
            response = masiv_plugin.executeAPIcall(lastCommit.object.url);
            out = masiv_plugin.apiResponse2Struct(response);

            %Process the data to make it easier to handle
            %Extract the date and time
            tok=regexp(out.committer.date,'(.*?)T(.*?)Z','tokens');
            if isempty(tok)
                error('Unable to get last date and time from commiter.date')
            end
            out.lastCommit.date = tok{1}{1};
            out.lastCommit.time = tok{1}{2};
            out.lastCommit.dateNum = datenum([tok{1}{1},' ',tok{1}{2}]); %The last commit in MATLAB serial date format

            %Store the URL of the repository (not the git URL)
            url = regexprep(url,'\.git$',''); 
            out.repositoryURL = url;

            out.branchName = branchName; %Store the branch we asked for
            out.repoName = masiv_plugin.getRepoName(url);

        end %getLastCommitDetails


        function limits=checkGitHubLimit
            % masiv_plugin.checkGitHubLimit
            %
            % function limits=checkGitHubLimit
            % 
            % Purpose: Query how many GitHub API requests remain from our IP address. 
            %          Returns a structure containing the results
            %
            %  limits.limit - the maximum number of available requests
            %  limits.remaining - how many requests remain
            %  limits.reset_unixTime - the time at which the limit resets (unix time)
            %  limits.reset_str - the time at which the limit resets (human-readable string)
            %
            % For details see: https://developer.github.com/v3/#rate-limiting

            U=urlread('https://api.github.com/rate_limit');
            tok=regexp(U,'"core".*?limit":(\d+).*?remaining":(\d+).*?reset":(\d+)','tokens'); 

            limits.limit=str2num(tok{1}{1});    
            limits.remaining=str2num(tok{1}{2});
            limits.reset_unixTime=str2num(tok{1}{3});   
            limits.reset_str=masiv_plugin.unixTime2str(limits.reset_unixTime);
        end %checkGitHubLimit


        function response = executeAPIcall(url)
            % masiv_plugin.executeAPIcall
            % Make an API call with simple error checking
            if ~masiv_plugin.checkLimit
                return
            end
            %Query to get the URL of the last commit
            try
                response=urlread(url);
            catch
                fprintf(' masiv_plugin FAILED to read data from API call: %s\n', url)
                rethrow(lasterror)
            end
        end %executeAPIcall


        function out=checkLimit
            % masiv_plugin.checkLimit
            %
            % Returns false and prints a message to the screen if you can't make any more API calls.
            % Returns true otherwise

            limits = masiv_plugin.checkGitHubLimit;
            if limits.remaining==0
                fprintf('GitHub has temporarily blocked API requests from your IP address. Resting at UTC %s\n',limits.reset_str)
                out=false;
            else
                out=true;
            end
        end %checkLimit


        function str = unixTime2str(unixTime)
            % masiv_plugin.unixTime2str
            % Converts a unix time to a human-readable string
            str=datestr(unixTime/86400 + datenum(1970,1,1));
        end %unixTime2str





        function out=apiResponse2Struct(response,verbose)
            % masiv_plugin.apiResponse2Struct
            %
            % out=apiResponse2Struct(response,verbose)
            %
            % Purpose: converts a string containing an API response to a structure

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
                [subsectionName,data] = masiv_plugin.processResponseSubsection(block);
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

        end %apiResponse2Struct


        function [subsectionName,data]=processResponseSubsection(response)
            % masiv_plugin.processResponseSubsection
            %
            % Extract data from an API response block in the form: 
            % "SUBECTIONNAME":{"KEY":"VALUE","KEY":VALUE}

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
        end %processResponseSubsection

    end %protected static methods



end %class
