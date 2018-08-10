#' AICc
#'
#' Compute Akaike Information Criterion corrected for small samples size (Warren and Seifert 2011).
#'
#' @param model Maxent object.
#' @param env \link{stack} or \link{brick} containing the environmental variables.
#' @param parallel logical, if TRUE it uses parallel computation, deafult is FALSE.
#'
#' @return The computed AICc
#' @export
#' @importFrom raster extract cellStats
#' @importFrom Rdpack reprompt
#'
#' @details You need package \pkg{snow} to use parallel computation. Parallel computation increases the speed
#' only for big datasets due to the time necessary to create the cluster.
#'
#' @references Warren D.L., Seifert S.N., (2011). Ecological niche modeling in Maxent:
#' the importance of model complexity and the performance of model selection criteria.
#' Ecological Applications, 21(2), 335–342.
#'
#' @examples \dontrun{
#' aicc(model, predictors, parallel = T)}
#'
#' @author Sergio Vignali
aicc <- function(model, env, parallel = FALSE){

  k <- nrow(model@coeff)

  if (k > nrow(model@presence@data)) {
    aicc <- NA
  } else {
    raw <- predict(model, env, type = "raw", parallel = parallel)
    raw_sum <- raster::cellStats(raw, sum)
    values <- raster::extract(raw, model@presence@coords)
    ll <- sum(log(values / raw_sum))
    aic <- 2 * k - 2 * ll
    aicc <- aic + (2 * k * (k + 1) / (nrow(model@presence@data) - k - 1))
  }

  return(round(aicc, 4))
}