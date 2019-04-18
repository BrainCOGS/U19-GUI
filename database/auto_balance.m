% class auto_balance

%Methods

%%% constructor
% function obj = auto_balance()
%
%%% returns 1 if balance connected properly, 0 otherwise
% function is_connected = verify_scale_connected(obj,verbose)
%
%%% returns current (instantanous) weight. returns -100 if there was a measurement error
% function cur_weight = get_current_weight(obj)
%
%%% returns a stable weight within a specified timeout window (default 60 sec).  returns -100 if there was a measurement error
% function stable_weight = get_stable_weight(obj,timeout_sec) %-100 means there was a measurement problem
%
%%% returns the average weight average for a given number of seconds.  returns -100 if there was a measurement error
% function sum_weight = avg_weight_n_sec(obj,n)
%
%%% monitors change in mouse presence and returns 1 if change is detected for a given timeout window, and updates ht MouseOn property. Otherwise returns 0
% function detected_change = detect_mouseOnOff(obj)
%
%%% resets the connection (currently not used)
% function reset_connection(obj)




classdef auto_balance < handle
  
  properties (Constant)
    DEFAULT_TIMEOUT   = 1.2
    VALID_WEIGHTS     = [14 40]
    WEIGHT_ACCURACY   = 0.1
  end
  
  properties (SetAccess = protected)
    MouseOn
    bal
    success

    lastPoll
    lastStable
    weightBuffer
    weightStable
  end
  
  methods
    function obj = auto_balance(portID)
      if nargin < 1; portID  = '/dev/tty.usbserial-DN02G2CX'; end
      obj.bal           = serial(portID);
      obj.bal.BaudRate  = 38400;
      obj.success       = true;
      try fopen(obj.bal); catch; obj.success = false; fclose(obj.bal); end
      obj.MouseOn       = 0;
      obj.lastStable    = [];
    end
    
    function is_connected = verify_scale_connected(obj,verbose)
      if nargin<2; verbose = false; end

      obj.bal.Timeout   = 5;        % for faster pinging
      fprintf(obj.bal,'PM'); pause(0.1)
      m = fscanf(obj.bal);
      if ~isempty(strfind(m,'Weighing'))
        if verbose; disp('Scale connected correctly'); end
        is_connected = true;
      else
        if verbose; disp('Scale connection error, perform manual weighing.'); end
        is_connected = false;
      end
      obj.bal.Timeout   = 10;       % restore original setting
    end
    
    function [weight,isWithinRange] = getMouseWeight(obj)
      weight          = obj.get_stable_weight;
      if weight > auto_balance.VALID_WEIGHTS(1) && weight < auto_balance.VALID_WEIGHTS(2)
        isWithinRange = true;
      else
        isWithinRange = false;
      end
    end
    
    %----- Poll the weight once, recording if stable and consecutive within the specified number of seconds
    function [weight, change, valid, isHigh, unit] = pollWeight(obj, minNumPolls, maxIntervalSecs)
      [weight, unit, stability] = obj.get_current_weight();
      
      if isempty(obj.lastPoll) || toc(obj.lastPoll) > maxIntervalSecs
        %% If last reading was too long ago, start over
%         toc(obj.lastPoll)
        obj.lastStable          = [];
        obj.weightBuffer        = [];
        obj.weightStable        = []; 
      end

      %% Record weight and stability
      obj.lastPoll              = tic;
      obj.weightBuffer(end+1)   = weight;
      obj.weightStable(end+1)   = isempty(stability);
      maxHistory                = 5 * minNumPolls;
      if numel(obj.weightBuffer) > maxHistory
        obj.weightBuffer        = obj.weightBuffer(end - maxHistory + 1:end);
        obj.weightStable        = obj.weightStable(end - maxHistory + 1:end);
      end
      
      %% Compute weight as the average over the last few stable readings
      iUnstable                 = find(obj.weightStable == false, 1, 'last');
      if isempty(iUnstable)
        iUnstable               = 0;
      end
      avgWeight                 = mean(obj.weightBuffer(iUnstable+1:end));
      isStable                  = max(avgWeight) - min(avgWeight) < auto_balance.WEIGHT_ACCURACY;
      if avgWeight < auto_balance.WEIGHT_ACCURACY
        isHigh                  = false;
      elseif avgWeight < auto_balance.VALID_WEIGHTS(1) || avgWeight > auto_balance.VALID_WEIGHTS(2)
        isHigh                  = nan;
      else
        isHigh                  = true;
      end
      
      %% Detect weight change upon a stable readout for the desired number of polls
      if      numel(obj.weightBuffer) - iUnstable < minNumPolls       ... not enough readings
          || ~isStable || ~isfinite(isHigh)                           %   not stable or not within range
        valid                   = false;
        change                  = 0;
      else
        %% Compute change w.r.t. last stable and valid readout
        valid                   = true;
        if isempty(obj.lastStable)
          change                = 0;
          obj.lastStable        = weight;
        else
          change                = sign( weight - obj.lastStable );
        end
        if change
          obj.lastStable        = weight;
        end
      end
    end
    
    %----- Override last stable readout value
    function setLastReadout(obj, value)
      obj.lastStable  = value;
    end
    
    %----- Tare scale
    function success = tare(obj)
      fprintf(obj.bal,'T');
      msg             = fscanf(obj.bal);
      success         = strncmpi(msg, 'ok', 2);
      obj.lastStable  = [];
    end
    
    
    function [cur_weight, unit, stability] = get_current_weight(obj) %-100 means there was a measurement problem
      fprintf(obj.bal,'IP');
      m = fscanf(obj.bal);
      mcell = textscan(m,'%f %s %s');
      if ~iscell(mcell) || ~isscalar(mcell{1})
        cur_weight=-100;
        unit = '';
        stability = '!';
      else
        cur_weight=mcell{1};
        unit = mcell{2}{:};
        stability = mcell{3}{:};
        fscanf(obj.bal);fscanf(obj.bal);fscanf(obj.bal);
      end
    end
    
    function stable_weight = get_stable_weight(obj,timeout_sec) %-100 means there was a measurement problem
      if nargin<2
        timeout_sec = auto_balance.DEFAULT_TIMEOUT;
      end
      
      max_diff_grams    = 0.3;
      measure_time      = 0.3;
      prev_weight       = avg_weight_n_sec(obj,2);
      
      tStart            = tic;
      while toc(tStart) < timeout_sec
        cur_weight      = avg_weight_n_sec(obj,measure_time);
        if abs(cur_weight -prev_weight)<max_diff_grams %reached stability
          stable_weight = cur_weight;
          break
        end
        prev_weight     = cur_weight;
        
      end
      stable_weight     = cur_weight;
    end
    
    function sum_weight = avg_weight_n_sec(obj,nsec)
      
      if nargin < 2; nsec = 0.3; end
      
      freq_weight        = 0.05; %Hz
      num_samples        = ceil(nsec*(1/freq_weight));
      sum_weight         = 0;
      actual_num_samples = 0;
      for l=1:num_samples
        cur_weight = get_current_weight(obj);
        if cur_weight>-100
          sum_weight         = sum_weight + cur_weight;
          actual_num_samples = actual_num_samples+1;
        end
        pause(freq_weight);
      end
      if actual_num_samples>0
        sum_weight = sum_weight/actual_num_samples;
      else
        sum_weight = -100;
      end
    end
    
    function detected_change = detect_mouseOnOff(obj)
      timeout = 60; %sec
      tic;
      detected_change = 0;
      while(toc<timeout)
        avg_weight = avg_weight_n_sec(obj,2);
        if obj.MouseOn==0 && avg_weight>10
          detected_change=1;
        end
        if obj.MouseOn==1 && avg_weight<10
          detected_change=1;
        end
        if detected_change
          obj.MouseOn = ~obj.MouseOn;
          break
        end
      end
    end
    
    function reset_connection(obj)
      portID = get(obj.bal,'Port');
      fclose(obj.bal);
      delete(obj.bal);
      obj.bal          = serial(portID);
      obj.bal.BaudRate = 38400;
      obj.success      = true;
      try fopen(obj.bal); catch; obj.success = false; fclose(obj.bal); end
    end
    
    function delete(obj)
      if isvalid(obj.bal)
        fclose(obj.bal);
        delete(obj.bal);
      end
    end
  end
end


