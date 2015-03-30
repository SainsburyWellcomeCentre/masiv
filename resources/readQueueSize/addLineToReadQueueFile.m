function addLineToReadQueueFile
	try
	    fid=fopen(readQueueFileFullPath, 'a');
	    fprintf(fid, '\n');
	    fclose(fid);
	catch
		fprintf('%s: failed with file name: %s\n',mfilename,readQueueFileFullPath)
		rethrow(lasterror)
	end


end