function addLineToReadQueueFile
    fid=fopen(readQueueFileFullPath, 'a');
    fprintf(fid, '\n');
    fclose(fid);
end