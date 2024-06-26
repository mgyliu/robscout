% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/gridge.R
\name{gridge2}
\alias{gridge2}
\title{"Graphical Ridge" - TODO there are issues with signs in the svd}
\usage{
gridge2(x, rho = c(0), svd_x = list())
}
\arguments{
\item{x}{a (n x p) data matrix. it should be standardized}

\item{rho}{a numeric vector of penalty terms}

\item{svd_x}{a list with names "d", "u", and "v". By default, gridge2
will compute the SVD of x. If svd_x is passed, then gridge will use
those values and not compute the SVD of x.}
}
\value{
a list of (svd_x, ws, rho) where:
\itemize{
\item `svd_x`` is the singular value decomposition of x
\item \code{w} is a list of length length(rho) containing the inverse precision matrix
estimates
\item \code{rho} is a vector of the penalty parameters that were used
}
}
\description{
\code{gridge2} computes the closed form solution of \eqn{\Theta^{-1}} which solves
\eqn{\Theta^{-1} - 2\lambda_1 \Theta = X^T X}
}
