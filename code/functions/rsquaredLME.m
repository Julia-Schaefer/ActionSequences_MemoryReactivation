function [R2_marginal, R2_conditional] = rsquaredLME(lme)
    % Extract variance components
    varFixed = var(lme.Fitted);                         % Variance of fixed effects
    varResidual = lme.Residuals.Raw' * lme.Residuals.Raw / lme.NumObservations; % Residual variance

    % Random effects variance (sum of all random terms)
    varRandom = sum(cellfun(@(x) x, lme.covarianceParameters, 'UniformOutput', true));

    % Marginal R² = fixed / (fixed + random + residual)
    R2_marginal = varFixed / (varFixed + varRandom + varResidual);

    % Conditional R² = (fixed + random) / total
    R2_conditional = (varFixed + varRandom) / (varFixed + varRandom + varResidual);
end