classdef SuperWaitBar<handle
    properties
        h
        x
        fname
        N
        timerObject
        msg
        textHandle
    end
    methods
        function obj=SuperWaitBar(N, msg)
            obj.N=N;
            %replace forward slashes which are not escape characters for "_"
            %with back-slash on Windows to avoid a storm of error messages.
            if ispc
                msg = regexprep(msg,'\\([^_])','/$1');
            end
            obj.h=waitbar(0, msg);
            obj.x=0;
            obj.msg=msg;
            obj.textHandle=findall(obj.h, 'Type', 'Text');
            %% Assign a unique file name
            obj.fname=fullfile(tempdir, ['progressbar_' num2str(randi(10000)) '.txt']);
            while exist(obj.fname,'file')
                obj.fname = fullfile(tempdir, ['/progressbar_' num2str(randi(10000)) '.txt']);
            end
            
            %% Open file
            f = fopen(obj.fname, 'w');
            if f<0
                error('Do you have write permissions for %s?', pwd);
            end
            %%
            fprintf(f, '%s\n', datestr(now)); % Save time started at the top of progress.txt
            fclose(f);
            
            obj.timerObject=timer('BusyMode', 'drop', 'ExecutionMode', 'fixedSpacing', 'Period', 0.05, 'TimerFcn', {@timerTick, obj});
            start(obj.timerObject);
        end
        function progress(obj)
            if ~exist(obj.fname, 'file')
                error([obj.fname ' not found. It must have been deleted.']);
            end

            f = fopen(obj.fname, 'a');
            fprintf(f, '1\n');
            fclose(f);

           
        end

        function delete(obj)
            stop(obj.timerObject)
            delete(obj.timerObject)
            delete(obj.fname)
            delete(obj.h)
            delete(obj)
        end
    end
end

function timerTick(~,~, obj)
    %% Get info from file
    f = fopen(obj.fname, 'r');
        timeStarted=fgetl(f);
        n = numel(fscanf(f, '%d'));
    fclose(f);
    %%
    fracComplete=n/obj.N;
    timeElapsed=now-datenum(timeStarted);
    
    rate=timeElapsed/fracComplete;
    timeLeftNum=(1-fracComplete)*rate;
    if isinf(timeLeftNum)
        timeLeftStr='Unknown';
    else
        timeLeftStr=datestr(timeLeftNum, 'HH:MM:SS');
    end
    
    x=fracComplete;
    obj.x=x;
    waitbar(x, obj.h)

    obj.textHandle.String=sprintf('%s \n(%u of %u, %s remaining)', obj.msg, n, obj.N, timeLeftStr);
            
    end

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

