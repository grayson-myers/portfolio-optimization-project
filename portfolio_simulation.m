function [t,X] = portfolio_simulation(muR,sigmaR,muS,sigmaS,investments,Xzero,t,M)
    % texit = zeros(M,1);
    X = zeros(M,length(t));
    for s = 1:M
        x = Xzero;
        X(s,1) = x;
        i = 2;
        while i <= length(t)
            dt = sqrt(t(i) - t(i-1));

            % split into safe and risky assets
            propR = investments(i-1); 
            propS = 1 - propR;

            XR = propR * x; %wealth in risky asset at time i
            XS = propS * x; %wealth in safe asset at time i

            %safe asset
            dW = sqrt(dt).*randn;
            XS = XS .* exp((muS - 0.5.*sigmaS.^2) .* dt + sigmaS .* dW);

            %risky asset
            sigmaI = (sigmaR(i) - sigmaR(i-1))/2;
            dW = sqrt(dt).*randn;
            XR = XR .* exp((muR - 0.5.*sigmaI.^2) .* dt + sigmaI .* dW);
            x = XR + XS;
            X(s,i) = x; % Store the current value of x in the trajectory array
           
            i = i + 1; % Increment the index for the next time step
        end
    end 
end