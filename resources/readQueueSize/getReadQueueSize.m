function n=getReadQueueSize
    if ~exist(readQueueFileFullPath, 'file')
        n=0;
    else
        fid=fopen(readQueueFileFullPath, 'r');
        n=0;
        while ~feof(fid)
            fgetl(fid);
            n=n+1;
        end
        fclose(fid);
        n=n-1;
    end
end