% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/scout_alternating.R
\name{betas_to_original_scale}
\alias{betas_to_original_scale}
\title{betas_to_original_scale}
\usage{
betas_to_original_scale(betamat, sdx, sdy)
}
\arguments{
\item{betamat}{a matrix where each column is a beta_hat estimate for some
regularization parameter}

\item{sdx}{a numeric vector. column SDs of original training X data}

\item{sdy}{a numeric value. SD of original training Y data}
}
\value{
betamat where each column is scaled by sdy/sdx
}
\description{
rescales betas to original scale of training data using the
standard deviation estimates of the X and Y training data.
}
