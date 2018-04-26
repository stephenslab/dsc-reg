# pipeline variables
# ==================
# $Y an n vector of outcomes (training data).
# $X an n by p matrix of covariates (training data).
# $Ytest an n vector of outcomes in test data.
# $Xtest an n by p matrix of covariates in test data.
# $beta_est an n vector of estimated values beta (learned
#   from training data).
# $error a scalar measure of accuracy.

# module groups
# =============
# simulate: -> $X, $Y, $Xtest, $Ytest
# analyze: $Y, $X -> $beta_est
# score: $beta_est, $Xtest, $Ytest -> $error

en_sim: R(source("code/simulate.R");
          d = en_sim(scenario))
  scenario: eg1, eg2, eg3, eg4, eg1b
  $Y: d$Y
  $X: d$X
  $Ytest: d$Ytest
  $Xtest: d$Xtest
  $beta_true: d$beta

sparse: R(source("code/simulate.R");
          d = simple_sim_regression(n,p,pve,pi0))
  scenario: sparse
  n: 100
  p: 100
  pve: 0.5
  pi0: 0.9
  $Y: d$Y
  $X: d$X
  $Ytest: d$Ytest
  $Xtest: d$Xtest
  $beta_true: d$beta

dense(sparse):
  scenario: dense
  pi0: 0

glmnet: glmnet_fit.R
  X: $X
  Y: $Y
  $beta_est: bhat

lasso(glmnet):
  alpha: 1

ridge(glmnet):
  alpha: 0

en(glmnet):
  alpha: 0.5

varbvs: R(fit = varbvs::varbvs(X,Z = NULL,y = Y))
  X: $X
  Y: $Y
  $beta_est: fit$beta

varbvsmix: R(fit  = varbvs::varbvsmix(X,Z = NULL,y = Y,
                                      sa = c(0,0.05,0.1,0.2,0.4));
             bhat = with(fit,rowSums(alpha * mu)))
  X: $X
  Y: $Y
  $beta_est: bhat

susie: R(fit = susieR::susie(X,Y = Y,L = L); bhat = susieR:::coef.susie(fit))
  L: 10
  X: $X
  Y: $Y
  $beta_est: bhat

susie2(susie):
  L: 20


  
pred_err: R(p = mean((X %*% b - Y)^2))
  b: $beta_est
  Y: $Ytest
  X: $Xtest
  $err: p
  
coef_err: R(c = mean((a - b)^2))
  b: $beta_est
  a: $beta_true
  $err: c

DSC:
  define:
    simulate: en_sim, sparse, dense
    analyze: lasso, ridge, en, susie, susie2, varbvs, varbvsmix
    score: pred_err, coef_err
  run: simulate * analyze * score
  exec_path: code
  R_libs: MASS, glmnet, varbvs@pcarbo/varbvs/varbvs-r,
          susieR@stephenslab/susieR
