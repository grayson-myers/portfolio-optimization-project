files = ["tsla_eod_202301.txt", "tsla_eod_202302.txt", "tsla_eod_202303.txt"];

data1 = table();

for k = 1:length(files)
    temp = readtable(files(k));
    data1 = [data1; temp];   % stack rows
end

%% 1. Data Loading and Initial Setup

Settle = datetime(data1.x_QUOTE_DATE_(1));
SpotPrice = data1.x_UNDERLYING_LAST_(1);
Rate = 0.045;

% FIXED: DTE is already DAYS → convert to YEARS properly
data1.T = data1.x_DTE_ / 365;

data1 = data1(data1.T > 0, :);

data1.C_markPrice = (data1.x_C_BID_ + data1.x_C_ASK_) / 2;

%% 2. Filtering and Grid Construction (SAFE VERSION)
idxNearMoney = data1.x_STRIKE_ > SpotPrice*0.85 & data1.x_STRIKE_ < SpotPrice*1.15;
dataFiltered = data1(idxNearMoney, :);

Strikes = unique(dataFiltered.x_STRIKE_);
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

%% 3. CLEAN DATA FOR CALIBRATION (IMPORTANT FIX)
validIdx = ~isnan(Prices);

TargetPrices = Prices(validIdx);
MATVec = MAT(validIdx);
STRVec = STR(validIdx);

%  prevent FFT memory crash (CRITICAL FIX)
maxObs = 150;
if length(TargetPrices) > maxObs
    r = randperm(length(TargetPrices), maxObs);
    TargetPrices = TargetPrices(r);
    MATVec = MATVec(r);
    STRVec = STRVec(r);
end

InstValid = fininstrument('Vanilla', ...
    'ExerciseDate', Settle + years(MATVec), ...
    'Strike', STRVec, ...
    'OptionType', 'call');

ZeroCurve = ratecurve("zero", Settle, Settle + years(max(MaturityValues)), Rate);

%% 4. Heston Calibration (UNCHANGED LOGIC)
objectiveFcn = @(Param) TargetPrices - price(finpricer('FFT', ...
    'Model', finmodel('Heston', ...
        'V0', Param(1), ...
        'ThetaV', Param(2), ...
        'Kappa', Param(3), ...
        'SigmaV', Param(4), ...
        'RhoSV', Param(5)), ...
    'SpotPrice', SpotPrice, ...
    'DiscountCurve', ZeroCurve), InstValid);

x0 = [0.04 0.06 1.5 0.4 -0.6];
lb = [1e-6 1e-6 1e-6 1e-6 -0.99];
ub = [1 1 10 2 0.99];

options = optimoptions('lsqnonlin', ...
    'Display','iter', ...
    'FunctionTolerance',1e-4);

Param = lsqnonlin(objectiveFcn, x0, lb, ub, options);

HestonModel = finmodel('Heston', ...
    'V0', Param(1), ...
    'ThetaV', Param(2), ...
    'Kappa', Param(3), ...
    'SigmaV', Param(4), ...
    'RhoSV', Param(5));

%% 5. VISUALIZATION (FIXED DIMENSIONS)
TMAT = yearfrac(Settle, Settle + years(MAT));

MKTVOL = blsimpv(SpotPrice, STR, Rate, TMAT, Prices);
MKTVOL = fillmissing(MKTVOL, 'nearest');

ModelPriceVec = price(finpricer('FFT', ...
    'Model', HestonModel, ...
    'SpotPrice', SpotPrice, ...
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

%% 6. BARrier OPTION (UNCHANGED BUT SAFE)
ExerciseDate = Settle + days(90);

BarrierOpt = fininstrument("Barrier", ...
    'Strike', 110, ...
    'ExerciseDate', ExerciseDate, ...
    'OptionType', "call", ...
    'ExerciseStyle', "american", ...
    'BarrierType', "DO", ...
    'BarrierValue', 80);

SimDates = Settle:days(1):ExerciseDate;

outPricer = finpricer("AssetMonteCarlo", ...
    'DiscountCurve', ZeroCurve, ...
    'Model', HestonModel, ...
    'SpotPrice', SpotPrice, ...
    'SimulationDates', SimDates);

[Price, outPR] = price(outPricer, BarrierOpt, "all");

fprintf('V0=%.4f Theta=%.4f Kappa=%.4f Sigma=%.4f Rho=%.4f\n', Param);
fprintf('Barrier Price = %.4f\n', Price);

disp(outPR.Results);

