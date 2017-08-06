function t=isGraphicsAvailable()

    t = usejava('jvm') && feature('ShowFigureWindows');

end