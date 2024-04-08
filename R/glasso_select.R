#' `huge_glasso_lambda_seq`
#' @description
#' Computes the lambda sequence for huge::huge.glasso
#' @param cov_X covariance matrix estimate
#' @param nlambda number of lambdas to return
#' @param lambda_min_ratio smallest value of lambda as a fraction of lambda_max
#' @return numeric vector of length nlambda, in decreasing order, of log-spaced
#' lambda values
huge_glasso_lambda_seq <- function(cov_X, nlambda, lambda_min_ratio) {
  p <- ncol(cov_X)
  lambda_max <- max(abs(cov_X - diag(p)))
  lambda_min <- lambda_min_ratio * lambda_max
  exp(seq(log(lambda_max), log(lambda_min), length = nlambda))
}


#' `glasso_select`
#' @description
#' Uses huge::huge.glasso to estimate an inverse covariance matrix given
#' a data matrix.
#' @param X feature matrix, \eqn{n \times p}
#' @param nlambda number of lambdas to optimize over
#' @param lambda_min_ratio smallest value of lambda as a fraction of lambda_max
#' @param crit criteria to select the optimal lambda. one of "bic" or "loglik"
#' @param scr whether to use lossy screening in huge.glasso
#' @param verbose whether to let huge.glasso print progress messages
#' @return list of:
#' * `icov`: matrix - inverse covariance estimate based on best lambda
#' * `best_lambda`: numeric - best lambda selected based on `crit`
#' * `lambda`: numeric vector - sequence of lambdas that was used for selection
#' * `errors`: numeric vector - `crit` values corresponding to each value in
#' `lambda`
#' @export
glasso_select <- function(X,
                          standardize, centerFun, scaleFun,
                          cov_method, crit,
                          nlambda, lambda_min_ratio,
                          scr = FALSE, verbose = FALSE) {
  # Center and scale X if needed
  if (standardize) {
    sdx <- apply(X, 2, scaleFun)
    X <- apply(X, 2, function(xi) (xi - centerFun(xi)) / scaleFun(xi))
  } else {
    sdx <- rep(1, ncol(X))
    # X <- scale(X, T, F)
  }

  cov_X <- est_cov(X, method = cov_method)
  # Pass in nlambda and lambda.min.ratio; let huge compute its own lambda sequence.
  hg_out <- huge::huge.glasso(cov_X, nlambda = nlambda, scr = scr, verbose = verbose, lambda.min.ratio = lambda_min_ratio)

  # Compute error criteria for each lambda
  errors <- unlist(lapply(hg_out$icov, function(icov) {
    icov_eval(icov, cov_X, nrow(X), method = crit)
  }))

  lambda <- hg_out$lambda
  best_idx <- which.min(errors)
  best_lambda <- lambda[best_idx]
  icovx <- hg_out$icov[[best_idx]]

  list(
    icovx = icovx, best_lambda = best_lambda,
    lambda = lambda, errors = errors
  )
}

#' @title icov_eval
#' @description Computes either a log likelihood or BIC criterion for
#' a given precisoin matrix estimate. `bic` is the BIC described in
#' (Yuan and Lin, 2007). `ebic` is the extended BIC described in
#' (Foygel and Drton, 2010). `loglik` is the log likelihood
#' @param icov inverse covariance estimate
#' @param cov covariance estimate
#' @param n number of rows in original data matrix
#' @param method one of "loglik", "bic", "ebic"
#' @export
icov_eval <- function(icov, cov, n, method = "ebic") {
  stopifnot(method %in% c("loglik", "bic", "ebic"))

  # negative log likelihood = - log |Theta| + tr(Theta * Sigma)
  neg_loglik <- -determinant(icov, logarithm = TRUE)$modulus[[1]] + sum(diag(icov %*% cov))

  if (method == "bic") {
    # esum is \sum_{i \leq j} \hat{e}_{ij}
    # where \hat{e}_ij = 0 if \Theta_{ij} = 0 and 1 otherwise
    # i.e., count how many unique pairs of variables have non-zero
    # partial correlation with each other (and include the diagonal)
    esum <- sum(abs(icov[lower.tri(icov, diag = T)]) > 1e-8)
    return(neg_loglik + (log(n) / n) * esum)
  }

  return(neg_loglik)
}