classdef yamlReadingTest < matlab.unittest.TestCase

    properties
        testYAMLDir = 'yamlFilesForTests'
        masivPrefsFname = 'testCaseVersionOfMasivPrefs.yml';
        fileStackWithZero = 'fileStackMetaFileWithAZeroLeadingFname.yml'
        fileStackWithChar = 'fileStackMetaFileWithACharacterLeadingFname.yml'

    end %properties



    %Open test method block
    methods (Test)

        function correctlyReadZeroNumericOnly(obj)            
            %Test whether we are loading a file name starting with a zero correctly
            fname = fullfile(obj.testYAMLDir,obj.fileStackWithZero);
            m=masiv.yaml.readSimpleYAML(fname);

            disp(m)
            obj.verifyClass(m.stackName, 'char')
            obj.verifyEqual(m.stackName,'01')
        end 
        function correctlyReadZeroMixedNumericChar(obj)            
            %Test whether we are loading a file name starting with a zero correctly
            fname = fullfile(obj.testYAMLDir,obj.fileStackWithZero);
            m=masiv.yaml.readSimpleYAML(fname);
            obj.verifyTrue(ischar(m.stackNameMixed));
            obj.verifyTrue(strcmp(m.stackNameMixed,'01_ANAME'));
        end 


        function correctlyReadStackFnameChar(obj)            
            %Test whether we are loading a file name starting with a character correctly
            fname = fullfile(obj.testYAMLDir,obj.fileStackWithChar);
            m=masiv.yaml.readSimpleYAML(fname);
            obj.verifyClass(m.stackName,'char');
            obj.verifyTrue(strcmp(m.stackName,'fileName'));
        end 


        %Test whether the navigation settings are being read correctly
        %This will address whether numeric values are correctly read and
        %the processes isn't being disrupted by the requirement for
        function correctlyReadNavigationSettings_zoomRate(obj)            
            fname = fullfile(obj.testYAMLDir,obj.masivPrefsFname);
            m=masiv.yaml.readSimpleYAML(fname);
            obj.verifyClass(m.navigation.zoomRate,'double');
            obj.verifyEqual(m.navigation.zoomRate,1.5);
        end 
        function correctlyReadNavigationSettings_scrollZoom(obj)            
            fname = fullfile(obj.testYAMLDir,obj.masivPrefsFname);
            m=masiv.yaml.readSimpleYAML(fname);
            obj.verifyClass(m.navigation.scrollZoomInvert,'double');
            obj.verifyEqual(m.navigation.scrollZoomInvert,1);
        end 
        function correctlyReadNavigationSettings_keyBoardUpdate(obj)            
            fname = fullfile(obj.testYAMLDir,obj.masivPrefsFname);
            m=masiv.yaml.readSimpleYAML(fname);
            obj.verifyClass(m.navigation.keyboardUpdatePeriod,'double');
            obj.verifyEqual(m.navigation.keyboardUpdatePeriod,0.005);
        end 
        function correctlyReadNavigationSettings_panMode(obj)            
            fname = fullfile(obj.testYAMLDir,obj.masivPrefsFname);
            m=masiv.yaml.readSimpleYAML(fname);
            obj.verifyTrue(m.navigation.panModeInvert,'double');
            obj.verifyEqual(m.navigation.panModeInvert,0)
        end 


        
    end %methods (Test)

end % yamlReadingTest < matlab.unittest.TestCase