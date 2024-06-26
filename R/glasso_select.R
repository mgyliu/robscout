#' `huge_glasso_lambda_seq`
#' @description
#' Computes the lambda sequence for huge::huge.glasso
#' @param S covariance matrix estimate cov(X)
#' @param nlambda number of lambdas to return
#' @param lambda.min.ratio smallest value of lambda as a fraction of lambda_max
#' @return numeric vector of length nlambda, in decreasing order, of log-spaced
#' lambda values
#' @export
huge_glasso_lambda_seq <- function(S, nlambda, lambda.min.ratio = 0.1) {
  d <- ncol(S)
  lambda.max <- max(max(S - diag(d)), -min(S - diag(d)))
  lambda.min <- lambda.min.ratio * lambda.max
  lambda <- exp(seq(log(lambda.max), log(lambda.min), length = nlambda))
  lambda
}

#' `glasso_cv`
#' @description
#' Performs K-fold cross-validation to select the best graphical model using
#' huge::huge.glasso
#' @param X feature matrix, \eqn{n \times p}
#' @param cov_method a string indicating which covariance matrix to use. One of "default" or "winsor"
#' @param folds a list of length K containing the indices of the test set in each CV fold
#' @param nlambda number of lambdas to optimize over
#' @param lambda.min.ratio smallest value of lambda as a fraction of lambda_max
#' @param lambdas sequence of lambda values. This function will generate its own lambda sequence
#' if this is NULL. If provided, `nlambda` and `lambda.min.ratio` are ignored.
#' @param crit criteria to select the optimal lambda. one of "ebic", "bic", or "loglik"
#' @param scr whether to use lossy screening in huge.glasso
#' @param verbose whether to let huge.glasso print progress messages
#' @return result of running huge::huge.glasso on the ideal lambda found from cv
#' @export
glasso_cv <- function(X, K, cov_method, crit, folds = NULL, nlambda = 100, lambda.min.ratio = 0.1, lambdas = NULL, scr = FALSE, verbose = FALSE) {
  if (is.null(folds)) {
    folds <- cv.folds(nrow(X), K)
  } else {
    # if user provided folds, do some checks to make sure they are valid
    stopifnot("folds should be of list type" = "list" %in% class(folds))
    stopifnot("length of folds should be the same as K" = length(folds) == K)
    all_fold_idx_valid <- all(lapply(folds, function(idx_vec) length(setdiff(idx_vec, 1:nrow(X)))) == 0)
    stopifnot("each set of indices in folds must be in the range of 1:nrow(X)" = all_fold_idx_valid)
  }

  S <- est_cov(X, method = cov_method)

  if (is.null(lambdas)) {
    lambdas <- huge_glasso_lambda_seq(S, nlambda = nlambda, lambda.min.ratio = lambda.min.ratio)
  }

  errors <- matrix(NA, nrow = length(lambdas), ncol = K)

  for (i in 1:K) {
    v_idx <- folds[[i]]
    X_train <- X[-v_idx, ]
    X_validation <- X[v_idx, ]

    res <- glasso_select(
      X_train, X_validation,
      cov_method, crit,
      lambdas = lambdas, scr = scr, verbose = verbose
    )

    errors[, i] <- res$errors
  }

  errors_avg_lambda <- apply(errors, MARGIN = 1, mean)
  best_lambda <- lambdas[which.min(errors_avg_lambda)]
  retval <- huge::huge.glasso(S, lambda = best_lambda, scr = scr, verbose = verbose)
  retval$lambda_seq <- lambdas
  retval$crit <- errors
  retval$cv.folds <- folds
  retval$input.cov <- S

  retval
}

#' `glasso_select`
#' @description
#' Uses huge::huge.glasso to estimate an inverse covariance matrix given
#' a data matrix.
#' @param X feature matrix, \eqn{n_1 \times p}
#' @param X.test feature matrix to test against, \eqn{n_2 \times p}
#' @param cov_method a string indicating which covariance matrix to use. See below for details
#' @param crit criteria to select the optimal lambda. one of "bic", "ebic", or "loglik"
#' @param nlambda number of lambdas to optimize over
#' @param lambda.min.ratio smallest value of lambda as a fraction of lambda_max
#' @param lambdas a sequence of lambda values (decreasing order). If provided,
#' `nlambda` and `lambda.min.ratio` are ignored
#' @param scr whether to use lossy screening in huge.glasso
#' @param verbose whether to let huge.glasso print progress messages
#' @details `cov_method` can be one of the following:
#' * `"default"`: computes the default covariance with \code{\link{cov}}
#' * `"winsor"`: computes the covariance matrix based on adjusted multivariate Winsorization,
#' as seen in Lafit et al. 2022.
#' @return list of:
#' * `icov`: matrix - inverse covariance estimate based on best lambda
#' * `best_lambda`: numeric - best lambda selected based on `crit`
#' * `lambda`: numeric vector - sequence of lambdas that was used for selection
#' * `errors`: numeric vector - `crit` values corresponding to each value in
#' `lambda`
#' @export
glasso_select <- function(X, X.test,
                          cov_method, crit,
                          nlambda = 100, lambda.min.ratio = 0.1,
                          lambdas = NULL,
                          scr = FALSE, verbose = FALSE) {
  S <- est_cov(X, method = cov_method)
  S.test <- est_cov(X.test, method = cov_method)

  hg_out <- if (is.null(lambdas)) {
    # Pass in nlambda and lambda.min.ratio; let huge compute its own lambda sequence.
    huge::huge.glasso(S, nlambda = nlambda, lambda.min.ratio = lambda.min.ratio, scr = scr, verbose = verbose, cov.output = TRUE)
  } else {
    # If lambdas is provided, use that and override the huge-computed sequences.
    huge::huge.glasso(S, lambda = lambdas, scr = scr, verbose = verbose, cov.output = TRUE)
  }

  # Compute error criteria for each lambda
  errors <- unlist(lapply(hg_out$icov, function(icov) {
    icov_eval(icov, S.test, nrow(X), method = crit)
  }))

  lambda <- hg_out$lambda
  best_idx <- which.min(errors)
  best_lambda <- lambda[best_idx]
  icovx <- hg_out$icov[[best_idx]]
  covx <- hg_out$cov[[best_idx]]

  list(
    icovx = icovx, covx = covx, best_lambda = best_lambda,
    lambda = lambda, errors = errors
  )
}

#' @title icov_eval
#' @description Computes either a log likelihood or BIC criterion for
#' a given precisoin matrix estimate. `bic` is the BIC described in
#' (Yuan and Lin, 2007). `loglik` is the log likelihood
#' @param icov inverse covariance estimate
#' @param cov covariance estimate
#' @param n number of rows in original data matrix
#' @param method one of "loglik", "bic", "ebic"
#' @export
icov_eval <- function(icov, cov, n, method = "ebic") {
  # `ebic` is the extended BIC described in (Foygel and Drton, 2010)``
  # not implemented for now since it is more suitable for p approx equal to n
  stopifnot(method %in% c("loglik", "bic", "ebic"))

  # negative log likelihood = - log |Theta| + tr(Theta * Sigma)
  neg_loglik <- -determinant(icov, logarithm = TRUE)$modulus[[1]] + sum(diag(icov %*% cov))

  # esum counts how many unique pairs of variables have non-zero
  # partial correlation with each other
  # i.e., the number of edges in the estimated graph
  esum <- sum(abs(icov[lower.tri(icov)]) > 1e-8)

  if (method == "bic") {
    return(neg_loglik + (log(n) / n) * esum)
  } else if (method == "ebic") {
    gamma <- 0.5
    p <- nrow(icov)
    return(neg_loglik + (log(n) / n) * esum + esum * gamma * 4 * log(p) / n)
  }

  return(neg_loglik)
}
