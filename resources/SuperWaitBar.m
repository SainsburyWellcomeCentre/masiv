classdef SuperWaitBar<handle
    properties
        h
        x
        fname
        N
        t
    end
    methods
        function obj=SuperWaitBar(N, msg)
            obj.N=N;
            obj.h=waitbar(0, msg);
            obj.x=0;
            
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
            fprintf(f, '%d\n', N); % Save N at the top of progress.txt
            fclose(f);
            
            obj.t=timer('BusyMode', 'drop', 'ExecutionMode', 'fixedSpacing', 'Period', 0.05, 'TimerFcn', {@timerTick, obj});
            start(obj.t);
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
            stop(obj.t)
            delete(obj.t)
            delete(obj.fname)
            delete(obj.h)
            delete(obj)
        end
    end
end
    function timerTick(~,~, obj)
    
    f = fopen(obj.fname, 'r');
    progress = fscanf(f, '%d');
    fclose(f);
    x=(length(progress)-1)/progress(1);
    obj.x=x;
    waitbar(x, obj.h)
            
end

