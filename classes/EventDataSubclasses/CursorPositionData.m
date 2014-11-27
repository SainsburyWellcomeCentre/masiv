classdef (ConstructOnLoad) CursorPositionData < event.EventData
   properties
      CursorPosition
   end

   methods
      function data = CursorPositionData(C)
         data.CursorPosition = C;
      end
   end
end
