function str = date2str(date, delimiter)

  if nargin < 2
    delimiter   = '/';
  end
  
%   str   = sprintf('%02d/%02d/%04d', date(2), date(3), date(1));
  str   = sprintf('%04d%s%02d%s%02d', date(1), delimiter, date(2), delimiter, date(3));

end
