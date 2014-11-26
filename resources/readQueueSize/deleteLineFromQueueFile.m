function deleteLineFromQueueFile
    n=getReadQueueSize;
    fid=fopen(readQueueFileFullPath, 'w');
    fprintf(fid, repmat('\n',1, n));
    fclose(fid);

end
