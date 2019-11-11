function deleteReadQueueFile

    if exist(readQueueFileFullPath, 'file')
        delete(readQueueFileFullPath)
    end

end

