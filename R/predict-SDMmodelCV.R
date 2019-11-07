#' Predict for Cross Validation
#'
#' Predict the output for a new dataset given a trained \code{\link{SDMmodelCV}}
#' model. The output is given as the provided function applied to the prediction
#' of the k models.
#'
#' @param object \code{\linkS4class{SDMmodelCV}} object.
#' @param data data.frame, \code{\linkS4class{SWD}} or raster
#' \code{\link[raster]{stack}} with the data for the prediction.
#' @param fun character. function used to combine the output of the k models,
#' default is \code{"mean"}. Note that fun is a character argument, you must use
#' \code{"mean"} and not \code{mean}. You can also pass a vector of character
#' containing multiple function names, see details.
#' @param type character. Output type, see details, used only for **Maxent** and
#' **Maxnet** methods, default is \code{NULL}.
#' @param clamp logical for clumping during prediction, used only for **Maxent**
#' and **Maxnet** methods, default is \code{TRUE}.
#' @param filename character. Output file name for the prediction map, if
#' provided the output is saved in a file.
#' @param format character. The output format, see
#' \code{\link[raster]{writeRaster}} for all the options, default is "GTiff".
#' @param extent \code{\link[raster]{Extent}} object, if provided it restricts
#' the prediction to the given extent, default is \code{NULL}.
#' @param parallel logical to use parallel computation during prediction,
#' default is \code{FALSE}.
#' @param ... Additional arguments to pass to the
#' \code{\link[raster]{writeRaster}} function.
#'
#' @details
#' * filename, format, extent, parallel and ... arguments are used only when the
#' prediction is done for a \code{\link[raster]{stack}} object.
#' * When a character vector is passed to the \code{fun} argument, than all the
#' given functions are applied and a named list is returned, see examples.
#' * For models trained with the **Maxent** method the argument \code{type} can
#' be: "raw", "logistic" and "cloglog".
#' * For models trained with the **Maxnet** method the argument \code{type} can
#' be: "link", "exponential", "logistic" and "cloglog", see
#' \code{\link[maxnet]{maxnet}} for more details.
#' * For models trained with the **ANN** method the function uses the "raw"
#' output type.
#' * For models trained with the **RF** method the output is the probability of
#' class 1.
#' * For models trained with the **BRT** method the function uses the number of
#' trees defined to train the model and the "response" output type.
#' * Parallel computation increases the speed only for large datasets due to the
#' time necessary to create the cluster. For **Maxent** models the function
#' performs the prediction in **R** without calling the **MaxEnt** Java
#' software. This results in a faster computation for large datasets and might
#' result in slightly different results compare to the Java software.
#'
#' @include SDMmodelCV-class.R
#' @importFrom raster beginCluster clusterR endCluster calc
#' @importFrom progress progress_bar
#'
#' @return A vector with the prediction or a \code{\link[raster]{raster}} object
#' if data is a raster \code{\link[raster]{stack}} or a list in the case of
#' multiple functions.
#' @exportMethod predict
#'
#' @author Sergio Vignali
#'
#' @references Wilson P.D., (2009). Guidelines for computing MaxEnt model output
#' values from a lambdas file.
#'
#' @examples
#' # Acquire environmental variables
#' files <- list.files(path = file.path(system.file(package = "dismo"), "ex"),
#'                     pattern = "grd", full.names = TRUE)
#' predictors <- raster::stack(files)
#'
#' # Prepare presence and background locations
#' p_coords <- virtualSp$presence
#' bg_coords <- virtualSp$background
#'
#' # Create SWD object
#' data <- prepareSWD(species = "Virtual species", p = p_coords, a = bg_coords,
#'                    env = predictors, categorical = "biome")
#'
#' # Create 4 random folds splitting only the presence data
#' folds <- randomFolds(data, k = 4, only_presence = TRUE)
#' model <- train(method = "Maxnet", data = data, fc = "l", folds = folds)
#'
#' # Make cloglog prediction for the all study area and get the result as
#' # average of the k models
#' predict(model, data = predictors, fun = "mean", type = "cloglog")
#'
#' # Make cloglog prediction for the all study area and get the average,
#' # standard deviation and maximum values of the k models
#' maps <- predict(model, data = predictors, fun = c("mean", "sd", "max"),
#'                 type = "cloglog")
#' plotPred(maps$mean)
#' plotPred(maps$sd)
#'
#' \donttest{
#' # Make logistic prediction for the all study area, given as standard
#' # deviation of the k models, and save it in a file
#' predict(model, data = predictors, fun = sd, type = "logistic",
#'         filename = "my_map")
#' }
setMethod(
  "predict", signature = "SDMmodelCV",
  definition = function(object, data, fun = "mean", type = NULL,
                        clamp = TRUE, filename = "", format = "GTiff",
                        extent = NULL, parallel = FALSE, ...) {
    on.exit(.end_prediction())

    k <- length(object@models)
    l <- length(fun)

    pb <- progress::progress_bar$new(
      format = "Predict [:bar] :percent in :elapsedfull",
      total = k + l, clear = FALSE, width = 60, show_after = 0)
    pb$tick(0)

    # Create empty output list
    output <- vector("list", length = l)

    if (inherits(data, "Raster")) {
      preds <- vector("list", length = k)

      if (parallel) {
        suppressMessages(raster::beginCluster())
        options(SDMtuneParallel = TRUE)
      }

      for (i in 1:k) {
        preds[[i]] <- predict(object@models[[i]], data = data,
                              type = type, clamp = clamp,
                              extent = extent, parallel = parallel)
        pb$tick(1)
      }
      preds <- raster::stack(preds)

      if (parallel) {
        for (i in 1:l) {
          output[[i]] <- raster::clusterR(preds, fun = raster::calc,
                                          args = list(fun = get(fun[i]),
                                                      filename = filename,
                                                      format = format, ...))
          pb$tick(1)
        }

      } else {
        for (i in 1:l) {
          output[[i]] <- raster::calc(preds, fun = get(fun[i]),
                                      filename = filename, format = format, ...)
          pb$tick(1)
        }
      }
    } else {
      if (class(data) == "SWD")
        data <- data@data
      preds <- matrix(nrow = nrow(data), ncol = k)
      for (i in 1:k) {
        preds[, i] <- predict(object@models[[i]], data = data, type = type,
                              clamp = clamp, ...)
        pb$tick(1)
      }
      for (i in 1:l) {
        output[[i]] <- apply(preds, 1, get(fun[i]), na.rm = TRUE)
        pb$tick(1)
      }
    }

    if (l == 1) {
      return(output[[1]])
    } else {
      names(output) <- fun
      return(output)
    }
  })

#' @importFrom raster endCluster
.end_prediction <- function() {
  options(SDMtuneParallel = FALSE)
  raster_option <- getOption("rasterCluster")
  if (!is.null(raster_option) && raster_option)
    raster::endCluster()
}