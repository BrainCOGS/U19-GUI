function index = getMonitorBySize(isLargest)
  
  if nargin < 1
    isLargest = true;
  end
  
  %%
  fcnSel      = {@min, @max};
  monitors    = get(0,'monitor');
  screenArea  = prod( monitors(:,3:end), 2 );
  [~,index]   = fcnSel{isLargest+1}(screenArea);
  
end
