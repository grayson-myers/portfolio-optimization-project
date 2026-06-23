

Settle = datetime(2015,7,10);
SpotPrice = 123.28;
Rate = -0.001;
MaturityDates = datetime([2015,8,21; 2015,9,18; 2015,12,18; 2016,4,15; 2016,6,17; 2017,1,20]);

Strikes = [115 120 125 130 135 140 145]';

Prices = [9.95 10.63 12.84 15.10 15.95 20.00; ...
    6.30 7.20 9.90 12.30 13.57 17.50; ...
    3.60 4.55 7.30 9.70 11.15 15.20; ...
    1.82 2.68 5.30 7.70 9.00 13.20; ...
    0.82 1.45 3.70 5.85 7.20 11.27; ...
    0.36 0.77 2.50 4.48 5.76 9.65; ...
    0.15 0.38 1.70 3.44 4.54 8.10];

ZeroCurve = ratecurve("zero", Settle, MaturityDates(end), Rate)



% Create fininstrument objects
[MAT, STR] = meshgrid(MaturityDates', Strikes);
Inst = fininstrument('Vanilla', 'ExerciseDate', MAT(:), ...
	'Strike', STR(:), 'OptionType', 'Call');

% Construct objective function
objectiveFcn = @(Param) Prices(:) - price(finpricer('FFT', 'Model', ...
	finmodel('Heston', 'V0', Param(1), 'ThetaV', Param(2), ...
	'Kappa', Param(3), 'SigmaV', Param(4), 'RhoSV', Param(5)), ...
	'SpotPrice', 123.28, 'DiscountCurve', ZeroCurve), Inst);

% Estimate model parameters
options = optimoptions('lsqnonlin', 'FunctionTolerance', 0.0001, ...
	'Display', 'final', 'PlotFcn', 'optimplotresnorm');
Param = lsqnonlin(objectiveFcn, [0.1 0.4 0.2 0.6 -0.1], [0 0 0 0 -1], ...
	[1 1 10 2 1], options);

HestonModel = finmodel('Heston', 'V0', Param(1), 'ThetaV', Param(2), ...
	'Kappa', Param(3), 'SigmaV', Param(4), 'RhoSV', Param(5))

% save the parameters in a .mat file so we can load it in a python script for Merton's optimization
% the parameters are everything we need for the merton's model
save('heston_params.mat', 'Param')


% Calculate implied volatilities for market and model prices
TMAT = yearfrac(ZeroCurve.Settle, MAT);
MKTVOL = blsimpv(123.28, STR, ZeroCurve.Rates(1), TMAT, Prices);

ModelPrice = price(finpricer('FFT', 'Model', HestonModel, 'SpotPrice', 123.28, ...
	'DiscountCurve', ZeroCurve), Inst);
ModelVol = blsimpv(123.28, STR(:), ZeroCurve.Rates(1), TMAT(:), ModelPrice);

% Plot implied volatility surface
figure
surf(TMAT, STR, MKTVOL)
hold on
scatter3(TMAT(:), STR(:), ModelVol, 'ro')
xlabel('Time to Maturity (years)')
ylabel('Strike Price')
zlabel('Implied Volatility')
hold off
grid on



% V = zeros(1, nSteps);
% V(1) = V0;
% for t = 2:nSteps
%     dW = sqrt(dt) * randn;
%     V(t) = max(V(t-1) + Kappa*(ThetaV - V(t-1))*dt + SigmaV*sqrt(max(V(t-1),0))*dW, 0);
% end