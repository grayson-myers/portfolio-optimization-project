function [t,X] = trajectory_simulation(mu,sigma,Xzero,t,M)
    % texit = zeros(M,1);
    X = zeros(M,length(t));
    for s = 1:M
        x = Xzero;
        X(s,1) = x;
        i = 2;
        while i <= length(t)
            dt = sqrt(t(i) - t(i-1));
            sigmaI = (sigma(i) - sigma(i-1))/2;
            dW = sqrt(dt).*randn;
            x = x .* exp((mu - 0.5.*sigmaI.^2) .* dt + sigmaI .* dW);
            X(s,i) = x; % Store the current value of x in the trajectory array
            i = i + 1; % Increment the index for the next time step
        end
    end 
end