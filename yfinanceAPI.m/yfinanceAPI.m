function data = yfinanceAPI(symbol, start_date, end_date, interval)
%% Purpose:
%
%  Get stock data through Yahoo Finance API
% 
%% Inputs:
%
%   symbol              cell                    Stock symbols 
%                                               {'AAPL','GOOGL'}
%
%   start_date          string                  'YYYY-MM-DD' format 
%                                               (e.g., '2024-01-15')
%
%   end_date            string                  'YYYY-MM-DD' format 
%                                               (e.g., '2024-01-20')
%
%   interval            string                  '1m', '30m','1h','1d','5d'
%                                               ('1d' is default)
%
%% Outputs:
%
%  data                 struct                  Stock Data for symbol(s)
%                                               which contain the 
%                                               following fields:
%                                               o = opening price
%                                               h = daily high price
%                                               l = daily low price
%                                               c = closing price
%                                               s = ticker symbol
%                                               t = time stamp (datenum)
%                                               a = adjusted closing price
%                                               only avail when interval =
%                                               1d
%% Revision History:
%  Darin C. Koblick                                         (c) 08-07-2025
%  Darin C. Koblick    Added Adjusted Closing Price             01-05-2026
%% ------------------------- Begin Code Sequence --------------------------
    if nargin == 0
          symbol = {'AAPL'};
      start_date = '2025-01-02';
        end_date = '2025-03-01';
        interval  = '1d';
         data = yfinanceAPI(symbol, start_date, end_date, interval);
         for ts=1:size(data,1)
             Open = data(ts).o;
             High = data(ts).h;
              Low = data(ts).l;
            Close = data(ts).c;
            tData = timetable(datetime(datestr(data(ts).t)),Open,High,Low,Close);

            figure('color',[1 1 1]);
            subplot(2,1,1);
            h = candle(tData,'k');
            for tp=2:numel(h)
               if Open(tp-1) > Close(tp-1)
                    set(h(tp),'FaceColor','r')
                    set(h(tp),'EdgeColor','r')
               else
                    set(h(tp),'FaceColor','w')
                    set(h(tp),'EdgeColor','g')
               end
            end
            title(sprintf('%s Stock Price', data(ts).s));
            xlim([datetime(start_date) datetime(end_date)]);
            ylabel('Share Price');
            subplot(2,1,2);
            bar(tData.Time,data(ts).v./1000000,'k');
            grid on;
            xlim([datetime(start_date) datetime(end_date)]);
            ylabel('Volume [Million]');
         end
        return;
    end
    % Convert dates to Unix timestamps
    start_timestamp = posixtime(datetime(start_date, 'InputFormat', 'yyyy-MM-dd'));
      end_timestamp = posixtime(datetime(end_date, 'InputFormat', 'yyyy-MM-dd'));
    % Interval can be [1m, 2m, 5m, 15m, 30m, 60m, 90m, 1h, 4h, 1d, 5d, 1wk, 1mo, 3mo]
    % we default to 1d, but can be 60m for any time period.
    if ~exist('interval','var')
        interval = '1d';
    end
    % Construct the Yahoo Finance API URL
                url = getData(symbol,start_timestamp,end_timestamp,interval);
    % Make the API request with proper headers
               data = repmat(struct(),[numel(url),1]);
for tu=1:numel(url)    
    try
        % Set up web options with headers to mimic a real browser
        options = weboptions('RequestMethod', 'GET');
        options.HeaderFields = {
            'User-Agent', ...
            ['Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36', ...
            ' (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'];
            'Accept', 'application/json, text/plain, */*';
            'Accept-Language', 'en-US,en;q=0.9';
            'Accept-Encoding', 'gzip, deflate, br';
            'Connection', 'keep-alive';
            'Referer', 'https://finance.yahoo.com/';
        };
        % Add timeout to prevent hanging
        options.Timeout = 30;
        fprintf('Fetching data from: %s\n', url{tu});
            response = webread(url{tu}, options);
      unix_timestamp = response.chart.result.timestamp;
        data(tu,1).t = datenum(datetime(unix_timestamp, 'ConvertFrom', 'posixtime'));
        data(tu,1).l = response.chart.result.indicators.quote.low; 
        data(tu,1).h = response.chart.result.indicators.quote.high; 
        data(tu,1).o = response.chart.result.indicators.quote.open;
        data(tu,1).c = response.chart.result.indicators.quote.close; 
        data(tu,1).v = response.chart.result.indicators.quote.volume;

       %Remove time outside of interval and NaN data:
                     idx = unix_timestamp < start_timestamp | ...
                           unix_timestamp > end_timestamp   |  ...
                           isnan(data(tu,1).v);        
       data(tu,1).t(idx) = [];
       data(tu,1).l(idx) = [];
       data(tu,1).h(idx) = [];
       data(tu,1).o(idx) = [];
       data(tu,1).c(idx) = [];
       data(tu,1).v(idx) = [];

       %Add adj closing price (if it exists)
            data(tu,1).a = NaN(size(data(tu,1).c));
        if isfield(response.chart.result.indicators,'adjclose')
            data(tu,1).a = response.chart.result.indicators.adjclose.adjclose;
        end

        data(tu,1).s = symbol{tu};
    catch ME
        fprintf('Error fetching data: %s\n', ME.message);
        fprintf('URL attempted: %s\n', url);
        fprintf('Try opening this URL in your browser to verify the data is available.\n');
    end
end
end 

function url = getData(symbol,start_timestamp,end_timestamp,interval)
 base_url = 'https://query2.finance.yahoo.com/v8/finance/chart/';
 url = cell(numel(symbol),1);
 for ts=1:numel(symbol)
      url{ts,1} = sprintf(['%s%s?period1=%d&period2=%d&interval=',interval], ...
                  base_url, lower(symbol{ts}), start_timestamp, end_timestamp);
 end
end