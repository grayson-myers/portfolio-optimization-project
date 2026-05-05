% %% 1. Data Loading and Initial Setup
% data1 = readtable("tsla_eod_202301.txt");
% 
% Settle = datetime(data1.x_QUOTE_DATE_(1));
% SpotPrice = data1.x_UNDERLYING_LAST_(1);
% Rate = 0.045;
% 
% % FIXED: DTE is already DAYS → convert to YEARS properly
% data1.T = data1.x_DTE_ / 365;
% 
% data1 = data1(data1.T > 0, :);
% 
% data1.C_markPrice = (data1.x_C_BID_ + data1.x_C_ASK_) / 2;
% 
% %% 2. Filtering and Grid Construction (SAFE VERSION)
% idxNearMoney = data1.x_STRIKE_ > SpotPrice*0.7 & data1.x_STRIKE_ < SpotPrice*1.3;
% dataFiltered = data1(idxNearMoney, :);
% 
% Strikes = unique(dataFiltered.x_STRIKE_);
% MaturityValues = unique(dataFiltered.T);
% 
% Prices = NaN(length(Strikes), length(MaturityValues));
% 
% for i = 1:length(Strikes)
%     for j = 1:length(MaturityValues)
% 
%         idx = (dataFiltered.x_STRIKE_ == Strikes(i)) & ...
%               abs(dataFiltered.T - MaturityValues(j)) < 1e-10;
% 
%         if any(idx)
%             Prices(i,j) = mean(dataFiltered.C_markPrice(idx), 'omitnan');
%         end
%     end
% end
% 
% [MAT, STR] = meshgrid(MaturityValues, Strikes);
% 
% %% 3. CLEAN DATA FOR CALIBRATION (IMPORTANT FIX)
% validIdx = ~isnan(Prices);
% 
% TargetPrices = Prices(validIdx);
% MATVec = MAT(validIdx);
% STRVec = STR(validIdx);
% 
% %  prevent FFT memory crash (CRITICAL FIX)
% maxObs = 150;
% if length(TargetPrices) > maxObs
%     r = randperm(length(TargetPrices), maxObs);
%     TargetPrices = TargetPrices(r);
%     MATVec = MATVec(r);
%     STRVec = STRVec(r);
% end
% 
% InstValid = fininstrument('Vanilla', ...
%     'ExerciseDate', Settle + years(MATVec), ...
%     'Strike', STRVec, ...
%     'OptionType', 'call');
% 
% ZeroCurve = ratecurve("zero", Settle, Settle + years(max(MaturityValues)), Rate);
% 
% %% 4. Heston Calibration (UNCHANGED LOGIC)
% objectiveFcn = @(Param) TargetPrices - price(finpricer('FFT', ...
%     'Model', finmodel('Heston', ...
%         'V0', Param(1), ...
%         'ThetaV', Param(2), ...
%         'Kappa', Param(3), ...
%         'SigmaV', Param(4), ...
%         'RhoSV', Param(5)), ...
%     'SpotPrice', SpotPrice, ...
%     'DiscountCurve', ZeroCurve), InstValid);
% 
% x0 = [0.04 0.06 1.5 0.4 -0.6];
% lb = [1e-6 1e-6 1e-6 1e-6 -0.99];
% ub = [1 1 10 2 0.99];
% 
% options = optimoptions('lsqnonlin', ...
%     'Display','iter', ...
%     'FunctionTolerance',1e-4);
% 
% Param = lsqnonlin(objectiveFcn, x0, lb, ub, options);
% 
% HestonModel = finmodel('Heston', ...
%     'V0', Param(1), ...
%     'ThetaV', Param(2), ...
%     'Kappa', Param(3), ...
%     'SigmaV', Param(4), ...
%     'RhoSV', Param(5));
% 
% %% 5. VISUALIZATION (FIXED DIMENSIONS)
% TMAT = yearfrac(Settle, Settle + years(MAT));
% 
% MKTVOL = blsimpv(SpotPrice, STR, Rate, TMAT, Prices);
% MKTVOL = fillmissing(MKTVOL, 'nearest');
% 
% ModelPriceVec = price(finpricer('FFT', ...
%     'Model', HestonModel, ...
%     'SpotPrice', SpotPrice, ...
%     'DiscountCurve', ZeroCurve), InstValid);
% 
% ModelVolVec = blsimpv(SpotPrice, STRVec, Rate, MATVec, ModelPriceVec);
% 
% figure
% surf(TMAT, STR, MKTVOL, 'FaceAlpha', 0.5)
% hold on
% scatter3(MATVec, STRVec, ModelVolVec, 'ro', 'filled')
% xlabel('Time to Maturity (years)')
% ylabel('Strike Price')
% zlabel('Implied Volatility')
% title('TSLA Market vs Heston Fit')
% grid on
% 
% %% 6. BARrier OPTION (UNCHANGED BUT SAFE)
% ExerciseDate = Settle + days(90);
% 
% BarrierOpt = fininstrument("Barrier", ...
%     'Strike', 110, ...
%     'ExerciseDate', ExerciseDate, ...
%     'OptionType', "call", ...
%     'ExerciseStyle', "american", ...
%     'BarrierType', "DO", ...
%     'BarrierValue', 80);
% 
% SimDates = Settle:days(1):ExerciseDate;
% 
% outPricer = finpricer("AssetMonteCarlo", ...
%     'DiscountCurve', ZeroCurve, ...
%     'Model', HestonModel, ...
%     'SpotPrice', SpotPrice, ...
%     'SimulationDates', SimDates);
% 
% [Price, outPR] = price(outPricer, BarrierOpt, "all");
% 
% fprintf('V0=%.4f Theta=%.4f Kappa=%.4f Sigma=%.4f Rho=%.4f\n', Param);
% fprintf('Barrier Price = %.4f\n', Price);
% 
% disp(outPR.Results);


% %% 1. Data Loading and Initial Setup
% files = ["tsla_eod_202301.txt","tsla_eod_202302.txt","tsla_eod_202303.txt", ...
%          "tsla_eod_202304.txt","tsla_eod_202305.txt","tsla_eod_202306.txt", ...
%          "tsla_eod_202307.txt","tsla_eod_202308.txt","tsla_eod_202309.txt", ...
%          "tsla_eod_202310.txt","tsla_eod_202311.txt","tsla_eod_202312.txt"];
% 
% data1 = table();
% 
% for k = 1:length(files)
%     data1 = [data1; readtable(files(k))];
% end
% 
% 
% Settle = datetime(data1.x_QUOTE_DATE_(1));
% SpotPrice = data1.x_UNDERLYING_LAST_(1);
% Rate = 0.045;
% 
% % FIXED: DTE is already DAYS → convert to YEARS properly
% data1.T = data1.x_DTE_ / 365;
% 
% data1 = data1(data1.T > 0, :);
% 
% data1.C_markPrice = (data1.x_C_BID_ + data1.x_C_ASK_) / 2;
% 
% %% 2. Filtering and Grid Construction (SAFE VERSION)
% idxNearMoney = data1.x_STRIKE_ > SpotPrice*0.7 & data1.x_STRIKE_ < SpotPrice*1.3;
% dataFiltered = data1(idxNearMoney, :);
% 
% Strikes = unique(dataFiltered.x_STRIKE_);
% MaturityValues = unique(dataFiltered.T);
% 
% Prices = NaN(length(Strikes), length(MaturityValues));
% 
% for i = 1:length(Strikes)
%     for j = 1:length(MaturityValues)
% 
%         idx = (dataFiltered.x_STRIKE_ == Strikes(i)) & ...
%               abs(dataFiltered.T - MaturityValues(j)) < 1e-10;
% 
%         if any(idx)
%             Prices(i,j) = mean(dataFiltered.C_markPrice(idx), 'omitnan');
%         end
%     end
% end
% 
% [MAT, STR] = meshgrid(MaturityValues, Strikes);
% 
% %% 3. CLEAN DATA FOR CALIBRATION (IMPORTANT FIX)
% validIdx = ~isnan(Prices);
% 
% TargetPrices = Prices(validIdx);
% MATVec = MAT(validIdx);
% STRVec = STR(validIdx);
% 
% %  prevent FFT memory crash (CRITICAL FIX)
% maxObs = 150;
% if length(TargetPrices) > maxObs
%     r = randperm(length(TargetPrices), maxObs);
%     TargetPrices = TargetPrices(r);
%     MATVec = MATVec(r);
%     STRVec = STRVec(r);
% end
% 
% InstValid = fininstrument('Vanilla', ...
%     'ExerciseDate', arrayfun(@(t) Settle + years(t), MATVec), ...
%     'Strike', STRVec, ...
%     'OptionType', repmat("call", size(STRVec)));
% 
% 
% ZeroCurve = ratecurve("zero", Settle, Settle + years(max(MaturityValues)), Rate);
% 
% %% 4. Heston Calibration (UNCHANGED LOGIC)
% objectiveFcn = @(Param) TargetPrices - price(finpricer('FFT', ...
%     'Model', finmodel('Heston', ...
%         'V0', Param(1), ...
%         'ThetaV', Param(2), ...
%         'Kappa', Param(3), ...
%         'SigmaV', Param(4), ...
%         'RhoSV', Param(5)), ...
%     'SpotPrice', SpotPrice, ...
%     'DiscountCurve', ZeroCurve), InstValid);
% 
% x0 = [0.04 0.06 1.5 0.4 -0.6];
% lb = [1e-6 1e-6 1e-6 1e-6 -0.99];
% ub = [1 1 10 2 0.99];
% 
% options = optimoptions('lsqnonlin', ...
%     'Display','iter', ...
%     'FunctionTolerance',1e-4);
% 
% Param = lsqnonlin(objectiveFcn, x0, lb, ub, options);
% 
% HestonModel = finmodel('Heston', ...
%     'V0', Param(1), ...
%     'ThetaV', Param(2), ...
%     'Kappa', Param(3), ...
%     'SigmaV', Param(4), ...
%     'RhoSV', Param(5));
% 
% %% 5. VISUALIZATION (FIXED DIMENSIONS)
% TMAT = yearfrac(Settle, Settle + years(MAT));
% 
% MKTVOL = blsimpv(SpotPrice, STR, Rate, TMAT, Prices);
% MKTVOL = fillmissing(MKTVOL, 'nearest');
% 
% ModelPriceVec = price(finpricer('FFT', ...
%     'Model', HestonModel, ...
%     'SpotPrice', SpotPrice, ...
%     'DiscountCurve', ZeroCurve), InstValid);
% 
% ModelVolVec = blsimpv(SpotPrice, STRVec, Rate, MATVec, ModelPriceVec);
% 
% figure
% surf(TMAT, STR, MKTVOL, 'FaceAlpha', 0.5)
% hold on
% scatter3(MATVec, STRVec, ModelVolVec, 'ro', 'filled')
% xlabel('Time to Maturity (years)')
% ylabel('Strike Price')
% zlabel('Implied Volatility')
% title('TSLA Market vs Heston Fit')
% grid on
% 
% %% 6. BARrier OPTION (UNCHANGED BUT SAFE)
% ExerciseDate = Settle + days(90);
% 
% BarrierOpt = fininstrument("Barrier", ...
%     'Strike', 110, ...
%     'ExerciseDate', ExerciseDate, ...
%     'OptionType', "call", ...
%     'ExerciseStyle', "american", ...
%     'BarrierType', "DO", ...
%     'BarrierValue', 80);
% 
% SimDates = Settle:days(1):ExerciseDate;
% 
% outPricer = finpricer("AssetMonteCarlo", ...
%     'DiscountCurve', ZeroCurve, ...
%     'Model', HestonModel, ...
%     'SpotPrice', SpotPrice, ...
%     'SimulationDates', SimDates);
% 
% [Price, outPR] = price(outPricer, BarrierOpt, "all");
% 
% fprintf('V0=%.4f Theta=%.4f Kappa=%.4f Sigma=%.4f Rho=%.4f\n', Param);
% fprintf('Barrier Price = %.4f\n', Price);
% 
% disp(outPR.Results);



%% 1. Data Loading and Initial Setup
files = ["tsla_eod_202301.txt","tsla_eod_202302.txt","tsla_eod_202303.txt", ...
         "tsla_eod_202304.txt","tsla_eod_202305.txt","tsla_eod_202306.txt", ...
         "tsla_eod_202307.txt","tsla_eod_202308.txt","tsla_eod_202309.txt", ...
         "tsla_eod_202310.txt","tsla_eod_202311.txt","tsla_eod_202312.txt"];

data1 = table();
for k = 1:length(files)
    data1 = [data1; readtable(files(k))];
end

% Pick a single calibration date — use first date in dataset
allDates       = datetime(data1.x_QUOTE_DATE_);
calibDate      = datetime('2023-07-03');   % change this to any date you want
data1          = data1(allDates == calibDate, :);

fprintf('Calibrating on date: %s\n', string(calibDate));
fprintf('Number of options on this date: %d\n', height(data1));

Settle    = calibDate;
SpotPrice = data1.x_UNDERLYING_LAST_(1);
Rate      = 0.045;

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

% Tighter filters to get clean, informative options
minMaturity  = 14/365;   % at least 2 weeks
maxMaturity  = 1.5;      % drop very long dated (noisy)
minPrice     = 1.00;     % higher floor — removes near-zero junk
maxPrice     = SpotPrice * 0.8; % removes deep ITM


% Tighter moneyness: 85% to 115% of spot only
minStrike    = SpotPrice * 0.85;
maxStrike    = SpotPrice * 1.15;

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

% Convert to IV space
MarketIVVec = blsimpv(SpotPrice, STRVec, Rate, MATVec, TargetPrices);

% Strict IV bounds — TSLA realistically 30% to 150%
validIV  = ~isnan(MarketIVVec) & MarketIVVec > 0.30 & MarketIVVec < 1.20;  % was 1.50
MarketIVVec  = MarketIVVec(validIV);
MATVec       = MATVec(validIV);
STRVec       = STRVec(validIV);
TargetPrices = TargetPrices(validIV);

fprintf('After IV filter: %d obs\n', length(MarketIVVec));
fprintf('IV range: %.4f to %.4f\n', min(MarketIVVec), max(MarketIVVec));
fprintf('MAT range: %.4f to %.4f\n', min(MATVec), max(MATVec));
fprintf('STR range: %.4f to %.4f\n', min(STRVec), max(STRVec));

% Stratified sampling — only needed if still over 150
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

% Build ZeroCurve and InstValid AFTER all filtering and sampling
ZeroCurve = ratecurve("zero", Settle, Settle + years(max(MaturityValues)), Rate);

InstValid = fininstrument('Vanilla', ...
    'ExerciseDate', arrayfun(@(t) Settle + years(t), MATVec), ...
    'Strike', STRVec, ...
    'OptionType', repmat("call", size(STRVec)));

fprintf('InstValid size: %d\n', length(InstValid));
fprintf('MATVec size: %d\n', length(MATVec));

%% 4. Heston Calibration
objectiveFcn = @(Param) [MarketIVVec - blsimpv(SpotPrice, STRVec, Rate, MATVec, ...
    price(finpricer('FFT', ...
        'Model', finmodel('Heston', ...
            'V0',     Param(1), ...
            'ThetaV', Param(2), ...
            'Kappa',  Param(3), ...
            'SigmaV', Param(4), ...
            'RhoSV',  Param(5)), ...
        'SpotPrice',     SpotPrice, ...
        'DiscountCurve', ZeroCurve), InstValid)); ...
    100 * max(0, Param(4)^2 - 2*Param(3)*Param(2))];   % Feller penalty

% Section 4 bounds
%% 4. Heston Calibration

lb = [1e-4   1e-4   0.1   0.05   -0.99];
ub = [1.0    1.0    25.0  3.0     0.99];   % free Sigma and Rho completely

startPoints = [0.04   0.04   1.5   0.3   -0.7;
               0.10   0.10   3.0   0.6   -0.5;
               0.25   0.20   5.0   1.0   -0.3;
               0.35   0.26   15.0  2.0   -0.2;   % close to July solution
               0.30   0.25   10.0  1.5   -0.3];  % slight variation
% startPoints = [0.04   0.04   1.5   0.3   -0.7;
%                0.10   0.10   3.0   0.6   -0.5;
%                0.25   0.20   5.0   1.0   -0.3;
%                0.50   0.50   8.0   0.8   -0.1;
%                0.80   0.80   2.0   0.5   -0.4;
%                1.00   1.00   10.0  0.9   -0.6];
               % 0.50   0.50   3.0   1.5   -0.9;   % high sigma, strong rho
               % 0.70   0.60   5.0   1.8   -0.8];  % high sigma, strong rho

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
fprintf('Best residual (IV space): %.6f\n', bestResidual);

% Check Feller condition
feller = 2*Param(3)*Param(2);
sigSq  = Param(4)^2;
fprintf('Feller condition: 2*Kappa*Theta=%.4f vs Sigma^2=%.4f  =>  %s\n', ...
    feller, sigSq, string(feller > sigSq));

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
scatter3(MATVec, STRVec, ModelVolVec, 'ro', 'filled')
xlabel('Time to Maturity (years)')
ylabel('Strike Price')
zlabel('Implied Volatility')
title('TSLA Market vs Heston Fit')
grid on

%% 6. Barrier Option Pricing
ExerciseDate = Settle + days(90);

BarrierOpt = fininstrument("Barrier", ...
    'Strike',        270, ...
    'ExerciseDate',  ExerciseDate, ...
    'OptionType',    "call", ...
    'ExerciseStyle', "american", ...
    'BarrierType',   "DO", ...
    'BarrierValue',  220);

SimDates = Settle:days(1):ExerciseDate;

outPricer = finpricer("AssetMonteCarlo", ...
    'DiscountCurve',    ZeroCurve, ...
    'Model',            HestonModel, ...
    'SpotPrice',        SpotPrice, ...
    'SimulationDates',  SimDates, ...
    'NumTrials',        100000);   % up from default 1000
     

[Price, outPR] = price(outPricer, BarrierOpt, "all");

fprintf('\nBarrier Option Price = %.4f\n', Price);
disp(outPR.Results);


% Plot market IV vs model IV to see fit quality
figure
scatter(STRVec, MarketIVVec, 'b', 'filled')
hold on
scatter(STRVec, ModelVolVec, 'r', 'filled')
xlabel('Strike')
ylabel('Implied Volatility')
legend('Market IV', 'Model IV')
title('Heston Fit Quality — Jan 3 2023')
grid on