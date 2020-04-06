classdef ScreenProperties
    %ScreenProperties Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Constant)
        
        LARGE_WIDTH    = 1920
        LARGE_HEIGHT   = 1080
        IS_SMALL_SCREEN = ScreenProperties.checkMonitorSize()
    end
        
    methods (Static)
        
        %----- Returns true if the screen size is smaller than a given area in pixels
        function isSmall = checkMonitorSize()
            monitors        = get(0,'ScreenSize');
            screenArea      = prod(monitors(1,3:end));
            isSmall         = screenArea < ScreenProperties.LARGE_WIDTH*ScreenProperties.LARGE_HEIGHT;
        end
    end
    
end

