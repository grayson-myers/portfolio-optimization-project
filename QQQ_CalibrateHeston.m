%% 1. Data Loading and Initial Setup
files = ["qqq_eod_201301.txt","qqq_eod_201302.txt","qqq_eod_201303.txt", ...
         "qqq_eod_201304.txt","qqq_eod_201305.txt","qqq_eod_201306.txt", ...
         "qqq_eod_201307.txt","qqq_eod_201308.txt","qqq_eod_201309.txt", ...
         "qqq_eod_201310.txt","qqq_eod_201311.txt","qqq_eod_201312.txt"];

data1 = table();
for k = 1:length(files)
    data1 = [data1; readtable(files(k))];
end

% Pick calibration date
allDates  = datetime(data1.x_QUOTE_DATE_);
calibDate = datetime('2013-07-01');
data1     = data1(allDates == calibDate, :);

fprintf('Calibrating on date: %s\n', string(calibDate));
fprintf('Number of options on this date: %d\n', height(data1));

Settle    = calibDate;
SpotPrice = data1.x_UNDERLYING_LAST_(1);
Rate      = 0.002;   % 2013 low-rate environment

data1.T = data1.x_DTE_ / 365;
data1   = data1(data1.T > 0, :);
data1.C_markPrice = (data1.x_C_BID_ + data1.x_C_ASK_) / 2;

%% 2. Filtering and Grid Construction
idxNearMoney = data1.x_STRIKE_ > SpotPrice*0.7 & data1.x_STRIKE_ < SpotPrice*1.3;
dataFiltered = data1(idxNearMoney, :);

Strikes        = unique(dataFiltered.x_STRIKE_);
MaturityValues = unique(dataFiltered.T);

Prices = NaN(length(Strikes), length(MaturityValues));

for i = 1:length(Strikes)
    for j = 1:length(MaturityValues)
        idx = (dataFiltered.x_STRIKE_ == Strikes(i)) & ...
              abs(dataFiltered.T - MaturityValues(j)) < 1e-10;
        if any(idx)
            Prices(i,j) = mean(dataFiltered.C_markPrice(idx), 'omitnan');
        end
    end
end

[MAT, STR] = meshgrid(MaturityValues, Strikes);

%% 3. Clean Data and Stratified Sampling
validIdx     = ~isnan(Prices);
TargetPrices = Prices(validIdx);
MATVec       = MAT(validIdx);
STRVec       = STR(validIdx);

% Filters tuned for QQQ (lower vol, tighter spreads)
minMaturity  = 14/365;
maxMaturity  = 1.5;
minPrice     = 0.25;
maxPrice     = SpotPrice * 0.6;

minStrike    = SpotPrice * 0.9;
maxStrike    = SpotPrice * 1.1;

keepFilter = MATVec >= minMaturity  & ...
             MATVec <= maxMaturity  & ...
             TargetPrices >= minPrice & ...
             TargetPrices <= maxPrice & ...
             STRVec >= minStrike    & ...
             STRVec <= maxStrike;

TargetPrices = TargetPrices(keepFilter);
MATVec       = MATVec(keepFilter);
STRVec       = STRVec(keepFilter);

fprintf('After moneyness/maturity filter: %d obs\n', length(TargetPrices));

% Convert to IV
MarketIVVec = blsimpv(SpotPrice, STRVec, Rate, MATVec, TargetPrices);

% IV bounds for QQQ
validIV = ~isnan(MarketIVVec) & MarketIVVec > 0.05 & MarketIVVec < 0.40;

MarketIVVec  = MarketIVVec(validIV);
MATVec       = MATVec(validIV);
STRVec       = STRVec(validIV);
TargetPrices = TargetPrices(validIV);

fprintf('After IV filter: %d obs\n', length(MarketIVVec));
fprintf('IV range: %.4f to %.4f\n', min(MarketIVVec), max(MarketIVVec));

% Stratified sampling
maxObs = 150;
if length(TargetPrices) > maxObs
    [~, sortIdx] = sortrows([MATVec, STRVec]);
    step    = floor(length(TargetPrices) / maxObs);
    keepIdx = sortIdx(1:step:end);
    keepIdx = keepIdx(1:min(maxObs, length(keepIdx)));

    TargetPrices = TargetPrices(keepIdx);
    MATVec       = MATVec(keepIdx);
    STRVec       = STRVec(keepIdx);
    MarketIVVec  = MarketIVVec(keepIdx);

    fprintf('After sampling: %d obs\n', length(MarketIVVec));
end

ZeroCurve = ratecurve("zero", Settle, Settle + years(max(MaturityValues)), Rate);

InstValid = fininstrument('Vanilla', ...
    'ExerciseDate', arrayfun(@(t) Settle + years(t), MATVec), ...
    'Strike', STRVec, ...
    'OptionType', repmat("call", size(STRVec)));

%% 4. Heston Calibration

objectiveFcn = @(Param) [ ...
    MarketIVVec - blsimpv(SpotPrice, STRVec, Rate, MATVec, ...
    price(finpricer('FFT', ...
        'Model', finmodel('Heston', ...
            'V0',     Param(1), ...
            'ThetaV', Param(2), ...
            'Kappa',  Param(3), ...
            'SigmaV', Param(4), ...
            'RhoSV',  Param(5)), ...
        'SpotPrice',     SpotPrice, ...
        'DiscountCurve', ZeroCurve), InstValid)); ...
    100 * max(0, Param(4)^2 - 2*Param(3)*Param(2))];

% QQQ-specific bounds
lb = [0.005  0.005  0.5   0.05   -0.95];
ub = [0.20   0.20   10.0  1.0    -0.1];

startPoints = [0.02   0.02   2.0   0.2   -0.6;
               0.04   0.03   3.0   0.3   -0.5;
               0.03   0.02   4.0   0.25  -0.5];

options = optimoptions('lsqnonlin', ...
    'Display',           'iter', ...
    'FunctionTolerance', 1e-6, ...
    'MaxIterations',     400);

bestParam    = [];
bestResidual = Inf;

for s = 1:size(startPoints, 1)
    fprintf('\n--- Start point %d ---\n', s);
    try
        [p, res] = lsqnonlin(objectiveFcn, startPoints(s,:), lb, ub, options);
        fprintf('Residual: %.6f\n', res);

        if res < bestResidual
            bestResidual = res;
            bestParam    = p;
        end
    catch ME
        fprintf('Start point %d failed: %s\n', s, ME.message);
    end
end

Param = bestParam;

fprintf('\nBest parameters:\n');
fprintf('V0=%.4f  Theta=%.4f  Kappa=%.4f  Sigma=%.4f  Rho=%.4f\n', Param);
fprintf('Best residual: %.6f\n', bestResidual);

HestonModel = finmodel('Heston', ...
    'V0',     Param(1), ...
    'ThetaV', Param(2), ...
    'Kappa',  Param(3), ...
    'SigmaV', Param(4), ...
    'RhoSV',  Param(5));

%% 5. Visualization
TMAT = yearfrac(Settle, Settle + years(MAT));

MKTVOL = blsimpv(SpotPrice, STR, Rate, TMAT, Prices);
MKTVOL = fillmissing(MKTVOL, 'nearest');

ModelPriceVec = price(finpricer('FFT', ...
    'Model',         HestonModel, ...
    'SpotPrice',     SpotPrice, ...
    'DiscountCurve', ZeroCurve), InstValid);

ModelVolVec = blsimpv(SpotPrice, STRVec, Rate, MATVec, ModelPriceVec);

figure
surf(TMAT, STR, MKTVOL, 'FaceAlpha', 0.5)
hold on
scatter3(MATVec, STRVec, ModelVolVec, 'r', 'filled')
xlabel('Time to Maturity')
ylabel('Strike')
zlabel('Implied Vol')
title('QQQ Market vs Heston Fit (2013)')
grid on

%% 6. Barrier Option Pricing

ExerciseDate = Settle + days(90);

BarrierOpt = fininstrument("Barrier", ...
    'Strike',        SpotPrice, ...
    'ExerciseDate',  ExerciseDate, ...
    'OptionType',    "call", ...
    'ExerciseStyle', "american", ...
    'BarrierType',   "DO", ...
    'BarrierValue',  SpotPrice * 0.8);

SimDates = Settle:days(1):ExerciseDate;

outPricer = finpricer("AssetMonteCarlo", ...
    'DiscountCurve',    ZeroCurve, ...
    'Model',            HestonModel, ...
    'SpotPrice',        SpotPrice, ...
    'SimulationDates',  SimDates, ...
    'NumTrials',        200000);

[Price, outPR] = price(outPricer, BarrierOpt, "all");

fprintf('\nBarrier Option Price = %.4f\n', Price);

%% 7. Fit Quality Plot
figure
scatter(STRVec, MarketIVVec, 'b', 'filled')
hold on
scatter(STRVec, ModelVolVec, 'r', 'filled')
xlabel('Strike')
ylabel('Implied Volatility')
legend('Market IV', 'Model IV')
title('QQQ Heston Fit Quality (2013)')
grid on