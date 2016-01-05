classdef (ConstructOnLoad) KeyPressEventData < event.EventData
   properties
      KeyPressData
   end

   methods
      function data = KeyPressEventData(d)
         data.KeyPressData = d;
      end
   end
end
