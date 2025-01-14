clear
close all


return_m_hor=readtable('return_monthly.xlsx','ReadVariableNames',true,'PreserveVariableNames',true,'Format','auto');


return_m=stack(return_m_hor,3:width(return_m_hor),'NewDataVariableName','return_m',...
'IndexVariableName','date');
writetable(return_m,'myPatientData.xlsx','WriteRowNames',true) 
return_m.date=char(return_m.date);
return_m.datestr=datestr(return_m.date);
return_m.date=datetime(return_m.datestr,'InputFormat','dd-MMM-yyyy','Locale','en_US');
return_m.return_m=return_m.return_m/100;


% Read the file with previous month market capitalizaiton 


market_cap_lm_hor=readtable('me_lag.xlsx','ReadVariableNames',true,'PreserveVariableNames',true,'Format','auto');
market_cap_lm=stack(market_cap_lm_hor,3:width(market_cap_lm_hor),'NewDataVariableName','lme',...
'IndexVariableName','date');
market_cap_lm.date=char(market_cap_lm.date);
market_cap_lm.datestr=datestr(market_cap_lm.date);
market_cap_lm.date=datetime(market_cap_lm.datestr,'InputFormat','dd-MMM-yyyy','Locale','en_US');

% merge two files 
return_monthly=outerjoin(return_m,market_cap_lm,'Keys',{'date','code','name','datestr'},'MergeKeys',true,'Type','left');
return_monthly=sortrows(return_monthly,{'code','date'},{'ascend','ascend'});

index=~isnan(return_monthly.lme);
return_monthly=return_monthly(index, : );


save return_m.mat return_monthly;

%%
%better edit date as yymm for we are conducting monthly analysis
return_monthly.yymm = year(return_monthly.date) * 12 + month(return_monthly.date);

% (b) Every K months, sort stocks into five groups based on previous K months' return and hold this position for K months. 
% What is the average equal-weighted return spread between high and low previous stock returns portfolios 
% for K = 1; 3; 6; 12; 24. Do you find that momentum exists in Chinese stock markets?

% First we create a new dataset with K = 1; 3; 6; 12; 24;, which denotes
% the frequency month returns.

% Define the values of K
K_values = [1, 3, 6, 12, 24];

%Looks like we have different opinions on this question. My opinion is, we
%should be sorting the stocks on "previous K months return" which should be
%a cumulative return not the return K months ago

% Loop over each value of K
for i = 1:length(K_values)
    K = K_values(i);
    table_height = size(return_monthly, 1);

    [G, code] = findgroups(return_monthly.code);
    k_month_return_handle = @(input) k_month_return(input, K);
    result_cell = splitapply(k_month_return_handle, return_monthly.return_m, G);
    % Create a new column that contains K months cummulative return every K
    % month, and name it "lagK"
    new_column = ['lag', num2str(K)];
    return_monthly.(new_column) = vertcat(result_cell{:});

    %Issue: this group index seems not used
    % Sort stocks into five groups based on previous K months' return
    %return_m_k = sort_stocks(return_m_k, K);

    % Displaying the results
    %disp(['Dataset with previous ', num2str(K), ' months return and sorted stocks:']);
    %disp(return_m_k);    
end

% So return_m_k is now our new dataset, based on the task in b).

%% Portfolio Analysis 

% We can split portfolio analysis into the follwing steps:
% Calculate the breakpoints that will be used to divide the sample into portfolios
% Use these breakpoints to form the portfolios
% Calculate the average value of the outcome variable Y with each portfolio for each period t
% Examine variation in these average values of Y across the different portfolios

% We have already formed the portfolios so we only have to do the last two
% steps.

% Number of portfolios
N = 5; %for different values of K

%This isn't quite right, e.g the numbers of bin==5 is 6 which is definitely
%not properly devided
% Sorting stocks into N portfolios based on lagged stock returns
%[~, edges, bin] = histcounts(return_m_k.return_m_lagged, N);
% We have already sorted stocks by return_m_k - must be specify to
% return_m_k.lagged


%loop for K
for i=1:5
    K = K_values(i);
    clear return_k_sorted

    %Extract needed rows
    indices = ~isnan(return_monthly.("lag"+num2str(K)));
    return_k = return_monthly(indices, ["code","name","yymm","lme","lag"+num2str(K)]);

    %holding return, every stock is held for K months, so the holding
    %return is simply the next value in "lagK"
    return_k.holding_return = [return_k.("lag"+num2str(K))(2:end); 0];

    %grouping the stocks into 5 groups by lagK on a certain time stamp
    return_k_sorted = lagged_return_port(return_k, 5, "yymm", "lag"+num2str(K));

    %group by yymm and portfolio
    [G, yymm, ir_port] = findgroups(return_k_sorted.yymm, return_k_sorted.lr_port);
    %equal weighted average return
    equal_weighted_avgr = splitapply(@mean, return_k_sorted.holding_return, G);
    ewavgr_table = table(yymm, ir_port, equal_weighted_avgr);
 
    ewavgr_unstack = unstack(ewavgr_table, "equal_weighted_avgr", "ir_port");
    %delete nan rows
    ewavgr_unstack = rmmissing(ewavgr_unstack, 1);
    %holding returns
    hold_return = @(input) cum_return(input, K);
    holding_returns = varfun(hold_return, ewavgr_unstack(:, 2:end));
    disp(holding_returns);
    %highest previous stock return minus lowest
    MOM_factor_k = ewavgr_unstack.x5 - ewavgr_unstack.x1;

    %saving data
    save(['ewavgr_unstack_',num2str(K),'months.mat'], "ewavgr_unstack");
    save(['MOM_factor_',num2str(K),'months.mat'], 'MOM_factor_k');
end


%I'm not sure but this paraphrase of codes seems unnecessary to me
%Computing value-weighted returns for each portfolio
%for i = 1:N
%    portfolioIdx = (bin == i);
%    return_m_k.portfolio_returns(portfolioIdx) = return_m_k.return_m(portfolioIdx) .* return_m_k.return_m_lagged(portfolioIdx); %.*return_m_k.me(portfolioIdx)
%end

%Bug: not "value-weighted", the project requires "equal-weighted"

% Calculating average //value_weighted// equal-weighted returns for each portfolio
%for i = 1:N
%    portfolioIdx = (bin == i);
%    average_returns(i) = nanmean(return_m_k.return_m(portfolioIdx));
%end



%%
%(c)
%load K=3 data
load("ewavgr_unstack_3months.mat","ewavgr_unstack");
load("MOM_factor_3months.mat", "MOM_factor_k");

%pca analysis
ewavgr_unstack = table2array(ewavgr_unstack(:, 2:end));
[coeff, ~, ~, ~, explained, mu] = pca(ewavgr_unstack);
factors = ewavgr_unstack*coeff;
PC1_3 = factors(:, 1:3);
%%




