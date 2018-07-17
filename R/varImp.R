#' Variable Importance
#'
#' Shows the percent contribution and permutation importance of the variable used to train the model.
#'
#' @param model Maxent object.
#'
#' @return A data frame with the variable importance.
#' @export
#'
#' @examples
#' \dontrun{
#' varContribution(model)}
#'
#' @author Sergio Vignali
varImp <- function(model) {

  if (class(model) != "Maxent") stop("Model must be a Maxent object!")

  input <- model@results
  pc <- input[grepl("contribution", rownames(input)), ]
  pi <- input[grepl("permutation.importance", rownames(input)), ]
  variables <- gsub(".contribution", "", names(pc))
  df <- data.frame(Variable = variables, Percent_contribution = round(pc, 1),
                   Permutation_importance = round(pi, 1),
                   row.names = NULL, stringsAsFactors = FALSE)

  df <- df[order(-df$Percent_contribution), ]
  row.names(df) <- NULL
  return(df)
}