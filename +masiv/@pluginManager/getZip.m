function unzippedDir = getZip(GitHubURL,branchName)
    % masiv.pluginManager.getZip
    %
    %Attempt to download the last commit as a ZIP file 
    %This doesn't involve an API call, so we do it first in case it fails because the number of API calls
    %from a given IP address are limited. See protected method "pluginManager.checkGitHubLimit" for details.
    %
    % Private method
    zipURL = masiv.pluginManager.getZipURL(GitHubURL,branchName);
    zipFname = sprintf('pluginManager_%s.zip',masiv.pluginManager.getRepoName(GitHubURL)); %Temporary location of the zip file (should work on Windows too)
    zipFname = fullfile(tempdir,zipFname);

    try 
        websave(zipFname,zipURL);
    catch
        fprintf('\nFAILED to download plugin ZIP file from %s\nCheck the URL you supplied and try again\n\n', zipURL);
        unzippedDir=[];
        return
    end

    %Now unpack the zip file in the temporary directory
    unzipFileList=unzip(zipFname,tempdir);
    delete(zipFname)

    %The name of the unzipped directory
    expression = ['(.*?\',filesep,masiv.pluginManager.getRepoName(GitHubURL),'-.+?\',filesep,')'];
    tok=regexp(unzipFileList{1},expression,'tokens');
    if isempty(tok)
        error('Failed to get zip file save location from zipfile list. Something stupid went wrong with install!')
    end

    unzippedDir = tok{1}{1};

    %Check that this folder indeed exists (super-paranoid here)
    if ~exist(unzippedDir,'dir')
        error('Expected to find the plugin unzipped at %s but it is not there\n', unzippedDir)
    end

end
