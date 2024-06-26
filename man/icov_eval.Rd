% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/glasso_select.R
\name{icov_eval}
\alias{icov_eval}
\title{icov_eval}
\usage{
icov_eval(icov, cov, n, method = "ebic")
}
\arguments{
\item{icov}{inverse covariance estimate}

\item{cov}{covariance estimate}

\item{n}{number of rows in original data matrix}

\item{method}{one of "loglik", "bic", "ebic"}
}
\description{
Computes either a log likelihood or BIC criterion for
a given precisoin matrix estimate. \code{bic} is the BIC described in
(Yuan and Lin, 2007). \code{loglik} is the log likelihood
}
