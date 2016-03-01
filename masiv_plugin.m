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
       exampleLastCommitDetails='{"ref":"refs/heads/master","url":"https://api.github.com/repos/raacampbell/neurTraceB/git/refs/heads/master","object":{"sha":"659edbe2aa065108d028aa3fdbbc89bd60ddc91f","type":"commit","url":"https://api.github.com/repos/raacampbell/neurTraceB/git/commits/659edbe2aa065108d028aa3fdbbc89bd60ddc91f"},"created_at": "2012-11-14T14:04:24Z","note": "getting-started","stuff":{"a":"wobble","b":"bobble"}}'
       exampleLastCommit='{"sha":"659edbe2aa065108d028aa3fdbbc89bd60ddc91f","url":"https://api.github.com/repos/raacampbell/neurTraceB/git/commits/659edbe2aa065108d028aa3fdbbc89bd60ddc91f","html_url":"https://github.com/raacampbell/neurTraceB/commit/659edbe2aa065108d028aa3fdbbc89bd60ddc91f","author":{"name":"Rob Campbell","email":"git@raacampbell.com","date":"2016-03-01T12:10:00Z"},"committer":{"name":"Rob Campbell","email":"git@raacampbell.com","date":"2016-03-01T12:10:00Z"},"tree":{"sha":"239bc4b7652c0b4e50719d862343c0f7d970183b","url":"https://api.github.com/repos/raacampbell/neurTraceB/git/trees/239bc4b7652c0b4e50719d862343c0f7d970183b"},"message":"also constructor name was wrong","parents":[{"sha":"04c987462e53a66ec72aa9ad0a134b3b240a93e2","url":"https://api.github.com/repos/raacampbell/neurTraceB/git/commits/04c987462e53a66ec72aa9ad0a134b3b240a93e2","html_url":"https://github.com/raacampbell/neurTraceB/commit/04c987462e53a66ec72aa9ad0a134b3b240a93e2"}]}'
    end



    methods (Static)


        function varargout=installPlugin(GitHubURL,targetDir,branchName)
            % Install MaSIV plugin from GitHub to a given target directory
            %
            % masiv_plugin.installPlugin 
            %
            % function installPlugin(GitHubURL,targetDir,branch)
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
            %   masiv_plugin.installPlugin('https://github.com/userName/repoName')
            %   masiv_plugin.installPlugin('https://github.com/userName/repoName.git')
            %   masiv_plugin.installPlugin('https://github.com/userName/repoName',[],'devel')
            %   masiv_plugin.installPlugin('https://github.com/userName/repoName','/path/to/stuff/')
            %            
            %
            % Rob Campbell - Basel 2016

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
                    ' You should either:\n    a) Delete this and try again.\n  or\n    b) Use masiv_plugin.updatePlugin to update it.\n\n'],targetLocation)
                return
            end

            %Attempt to download the last commit as a ZIP file 
            %This doesn't involve an API call, so we do it first in case it fails because the number of API calls
            %from a given IP address are limited. See protected method "masiv_plugin.checkGitHubLimit" for details.
            zipURL = masiv_plugin.getZipURL(GitHubURL,branchName);
            zipFname =sprintf('masiv_plugin_%s.zip',repoName); %Temporary location of the zip file (should work on Windows too)
            tmpDir = '/tmp';
            zipFname = fullfile(tmpDir,zipFname);

            try 
                websave(zipFname,zipURL);
            catch
                fprintf('\nFAILED to download plugin ZIP file from %s.\nCheck the URL you supplied and try again\n\n', zipURL)
                return
            end

            %Now unpack the zip file in the temporary directory
            unzipFileList=unzip(zipFname,tmpDir);

            %The name of the unzipped directory
            tok=regexp(unzipFileList{1},['(.*?',filesep,repoName,'-.+?',filesep,')'],'tokens');
            if isempty(tok)
                error('Failed to get zip file save location from zipfile list. Something stupid went wrong with installPlugin!')
            end
            unzippedDir = tok{1}{1};


            %Now we query GitHub using the GitHub API in order to log the time this commit was made and the commit's SHA hash
            details=masiv_plugin.getLastCommitDetails(GitHubURL,branchName);


            fprintf('Plugin last updated by %s at %s on %s\n', ...
                details.author.name, details.lastCommit.time, details.lastCommit.date) 

            %Save this structure in the unpacked zip directory
            save(fullfile(unzippedDir,masiv_plugin.detailsFname),'details')


            %Now we move the directory to the target directory and rename it to the repository name
            fprintf('Attempting to install repository "%s" in directory "%s"\n', repoName, targetLocation)
            movefile(unzippedDir,targetLocation)

            if nargout>0
                varargout{1}=details;
            end

        end %installPlugin

        function updatePlugin(pathToPluginDir)  
            % Install MaSIV plugin from GitHub to a given target directory
            %
            % masiv_plugin.updatePlugin
            %
            % function updatePlugin(pathToPluginDir)
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
            %   masiv_plugin.updatePlugin('/path/to/plugin/')
            %            
            %
            % Rob Campbell - Basel 2016

            if ~exist(pathToPluginDir,'dir')
                fprintf('No directory found at %s\n',pathToPluginDir)
                return
            end

            if ~exist(fullfile(pathToPluginDir,masiv_plugin.detailsFname),'file')
                fprintf('\n Could not find a "%s" file in directory "%s".\n Please install plugin with "masiv_plugin.installPlugin"\n\n',...
                    masiv_plugin.detailsFname,pathToPluginDir)
                return
            end

            %TODO: nothing happens here yet


        end %updatePlugin
 


     
    end % static methods




    methods (Access=protected, Static)

        function isplugin=isMasivPlugin(fileName)
            % masiv_plugin.isMasivPlugin
            %
            % function isplugin=isMasivPlugin(fileName)
            %
            % Purpose: return true if an m file is a valid MaSIV plugin
            %
            % Example:
            % masiv_plugin.isMasivPlugin('myPluginFile.m')

            [~,className]=fileparts(fileName);
            m=meta.class.fromName(className);
            if ismember('masivPlugin', {m.SuperclassList.Name})
                isplugin=true;
            else
                isplugin=false;
            end
        end %isMasivPlugin


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

        end %getZipURL



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

            out.repositoryURL = url; %Store the URL from which we obtained the repository
            out.branchName = branchName; %Store the branch we asked for

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


