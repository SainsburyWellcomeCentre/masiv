classdef (ConstructOnLoad) CursorPositionData < event.EventData
   properties
      CursorPosition
      PixelIntensity
   end

   methods
      function data = CursorPositionData(C, v)
         data.CursorPosition = C;
         data.PixelIntensity=v;
      end
   end
end
