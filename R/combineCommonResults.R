#' Combine SingleR results with common genes
#'
#' Combine results from multiple runs of \code{\link{classifySingleR}} (usually against different references) into a single \linkS4class{DataFrame}.
#' For each cell, the label from the result with the highest score is used as that cell's combined label.
#' This assumes that each run of \code{\link{classifySingleR}} was performed using a common set of marker genes,
#' hence the \code{Common} in the function name.
#'
#' @param results A list of \linkS4class{DataFrame} prediction results as returned by \code{\link{classifySingleR}} when run on each reference separately.
#'
#' @return A \linkS4class{DataFrame} is returned containing the annotation statistics for each cell or cluster (row).
#' This mimics the output of \code{\link{classifySingleR}} and contains the following fields:
#' \itemize{
#' \item \code{scores}, a numeric matrix of correlations formed by combining the equivalent matrices from \code{results}.
#' \item \code{labels}, a character vector containing the per-cell combined label across references.
#' \item \code{references}, an integer vector specifying the reference from which the combined label was derived.
#' \item \code{orig.results}, a DataFrame containing \code{results}.
#' }
#' It may also contain \code{first.labels} and \code{pruned.labels} if these were also present in \code{results}.
#'
#' The \code{\link{metadata}} contains \code{common.genes},
#' a character vector of the common genes that were used across all references in \code{results}.
#' 
#' @details
#' For each cell, we identify the reference with the highest score across all of its labels.
#' The \dQuote{combined label} is then defined as the label assigned to that cell in the highest-scoring reference.
#' (The same logic is also applied to the first and pruned labels, if available.)
#' See comments in \code{?"\link{combine-predictions}"} for the overall rationale.
#' 
#' Each result should be generated from training sets that use a common set of genes during classification, 
#' i.e., \code{common.genes} should be the same in the \code{trained} argument to each \code{\link{classifySingleR}} call.
#' This is because the scores are not comparable across results if they were generated from different sets of genes.
#' It is also for this reason that we use the highest score prior to fine-tuning, 
#' even if it does not correspond to the score of the fine-tuned label.
#'
#' It is highly unlikely that this function will be called directly by the end-user.
#' Users are advised to use the multi-reference mode of \code{\link{SingleR}} and related functions,
#' which will take care of the use of a common set of genes before calling this function to combine results across references.
#'
#' @author 
#' Jared Andrews,
#' Aaron Lun
#'
#' @examples
#' # Making up data (using one reference to seed another).
#' ref <- .mockRefData(nreps=8)
#' ref1 <- ref[,1:2%%2==0]
#' ref2 <- ref[,1:2%%2==1]
#' ref2$label <- tolower(ref2$label)
#'
#' test <- .mockTestData(ref1)
#'
#' # Applying classification with SingleR's multi-reference mode.
#' ref1 <- scater::logNormCounts(ref1)
#' ref2 <- scater::logNormCounts(ref2)
#' test <- scater::logNormCounts(test)
#'
#' pred <- SingleR(test, list(ref1, ref2), labels=list(ref1$label, ref2$label))
#' pred[,1:5] # Only viewing the first 5 columns for visibility.
#'
#' @seealso
#' \code{\link{SingleR}} and \code{\link{classifySingleR}}, for generating predictions to use in \code{results}.
#'
#' \code{\link{combineRecomputedResults}}, for another approach to combining predictions.
#'
#' @export
#' @importFrom S4Vectors DataFrame metadata metadata<-
combineCommonResults <- function(results) {
    if (length(unique(lapply(results, rownames))) != 1) {
        stop("cell/cluster names in 'results' are not identical")
    }
    if (length(unique(vapply(results, nrow, 0L)))!=1) {
        stop("numbers of cells/clusters in 'results' are not identical")
    }

    all.common <- lapply(results, function (x) sort(metadata(x)$common.genes))
    if (length(unique(all.common)) != 1) {
        # This should be changed to 'stop' before release/after merge with PR #60.
        warning("common genes are not identical")
    }

    ncells <- nrow(results[[1]])
    collected.scores <- collected.best <- vector("list", length(results))
    for (i in seq_along(results)) {
        scores <- results[[i]]$scores
        collected.best[[i]] <- scores[cbind(seq_len(ncells), max.col(scores))]
        collected.scores[[i]] <- scores
    }

    all.scores <- do.call(cbind, collected.scores)
    output <- DataFrame(scores = I(all.scores), row.names=rownames(results[[1]]))
    metadata(output)$common.genes <- all.common[[1]]

    chosen <- max.col(do.call(cbind, collected.best))
    cbind(output, .combine_result_frames(chosen, results))
}

#' @importFrom S4Vectors DataFrame metadata metadata<-
.combine_result_frames <- function(chosen, results) {
    has.first <- !is.null(results[[1]]$first.labels)
    has.pruned <- !is.null(results[[1]]$pruned.labels)

    # Organizing the statistics based on the chosen results.
    chosen.label <- chosen.first <- chosen.pruned <- rep(NA_character_, nrow(results[[1]]))

    for (u in unique(chosen)) {
        current <- chosen==u
        res <- results[[u]]
        chosen.label[current] <- res$labels[current]

        if (has.first) { # assume that either everyone has 'first', or no-one does.
            chosen.first[current] <- res$first.labels[current]
        }

        if (has.pruned) { # same for pruned.
            chosen.pruned[current] <- res$pruned.labels[current]
        }
    }

    output <- DataFrame(labels=chosen.label, row.names=rownames(results[[1]]))

    if (has.first) {
        output$first.labels <- chosen.first
        output <- output[,c("first.labels", "labels"),drop=FALSE]
    }

    if (has.pruned) {
        output$pruned.labels <- chosen.pruned
    }

    # Collating some DE statistics.
    if (has.de <- !is.null(metadata(results[[1]])$de.genes)) {
        collected.de <- vector("list", length(results))
        for (i in seq_along(results)) {
            collected.de[[i]] <- metadata(results[[i]])$de.genes
        }
        metadata(output)$de.genes <- do.call(c, collected.de)
    }

    output$reference <- chosen

    if (is.null(names(results))) {
        names(results) <- sprintf("ref%i", seq_along(results))
    }
    output$orig.results <- do.call(DataFrame, lapply(results, I))

    output
}