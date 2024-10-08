# This tests the classification *without* fine-tuning.
# (Tests with fine-tuning are handled by 'test-SingleR.R'.)
# library(testthat); library(SingleR); source("setup.R"); source("test-classify.R")

trained <- trainSingleR(training, training$label)

test_that("correlations are computed correctly by classifySingleR", {
    Q <- 0.8
    out <- classifySingleR(test, trained, fine.tune=FALSE, quantile=Q)

    # Computing reference correlations between test and trained.
    y <- split(seq_along(training$label), training$label)
    collected <- matrix(0, ncol(test), length(y))
    colnames(collected) <- names(y)
    genes <- trained$markers$unique

    for (x in seq_along(y)) {
        ref <- cor(assay(training)[genes,y[[x]]], assay(test)[genes,], method="spearman")
        collected[,x] <- apply(ref, 2, FUN=quantile, prob=Q)
    }

    # Checking that they're the same.
    expect_equal(collected, out$scores[,colnames(collected)])

    # Checking that the correct label is chosen.
    expect_identical(colnames(collected)[max.col(collected)], out$labels)
})

test_that("classifySingleR behaves sensibly with very low 'quantile' settings", {
    Q <- 0
    out <- classifySingleR(test, trained, fine.tune=FALSE, quantile=Q)

    # Computing reference correlations between test and trained.
    y <- split(seq_along(training$label), training$label)
    collected <- matrix(0, ncol(test), length(y))
    colnames(collected) <- names(y)
    genes <- trained$markers$unique

    for (x in seq_along(y)) {
        ref <- cor(assay(training)[genes,y[[x]]], assay(test)[genes,], method="spearman")
        collected[,x] <- apply(ref, 2, FUN=min)
    }

    # Checking that they're the same.
    expect_equal(collected, out$scores[,colnames(collected)])
    expect_identical(colnames(collected)[max.col(collected)], out$labels)
})

test_that("classifySingleR behaves sensibly with very large 'quantile' settings", {
    Q <- 1
    out <- classifySingleR(test, trained, fine.tune=FALSE, quantile=Q)

    # Computing reference correlations between test and trained.
    y <- split(seq_along(training$label), training$label)
    collected <- matrix(0, ncol(test), length(y))
    colnames(collected) <- names(y)
    genes <- trained$markers$unique

    for (x in seq_along(y)) {
        ref <- cor(assay(training)[genes,y[[x]]], assay(test)[genes,], method="spearman")
        collected[,x] <- apply(ref, 2, FUN=max)
    }

    # Checking that they're the same.
    expect_equal(collected, out$scores[,colnames(collected)])
    expect_identical(colnames(collected)[max.col(collected)], out$labels)
})

test_that("classifySingleR behaves with no-variance cells", {
    sce <- test 
    logcounts(sce)[,1:10] <- 0

    Q <- 0.2
    out <- classifySingleR(sce, trained, fine.tune=FALSE, quantile=Q)
    expect_true(all(abs(out$scores[1:10,] - 0.5) < 1e-8)) # works out to 0.5, as a mathematical oddity.

    ref <- classifySingleR(test, trained, fine.tune=FALSE, quantile=Q)
    expect_identical(out$scores[-(1:10),], ref$scores[-(1:10),])
    expect_identical(out$labels[-(1:10)], ref$labels[-(1:10)])
})

test_that("classifySingleR works with multiple references", {
    training1 <- training2 <- training
    training1 <- training1[sample(nrow(training1)),]
    rownames(training1) <- rownames(training)

    mtrain <- trainSingleR(list(training1, training2), list(training1$label, training2$label))
    out <- classifySingleR(test, mtrain)
    expect_identical(names(out$orig.results), c("ref1", "ref2"))
    expect_true(all(out$reference %in% 1:2))

    ref1 <- classifySingleR(test, mtrain[[1]])
    ref2 <- classifySingleR(test, mtrain[[2]])
    expect_identical(out, combineRecomputedResults(list(ref1, ref2), test, mtrain))

    # Preserves names of the references themselves.
    mtrain <- trainSingleR(list(foo=training1, bar=training2), list(training1$label, training2$label))
    out <- classifySingleR(test, mtrain)
    expect_identical(names(out$orig.results), c("foo", "bar"))
    expect_true(all(out$reference %in% 1:2))
})

test_that("classifySingleR behaves with silly inputs", {
    out <- classifySingleR(test[,0], trained, fine.tune=FALSE)
    expect_identical(nrow(out$scores), 0L)
    expect_identical(length(out$labels), 0L)
    expect_error(classifySingleR(test[0,], trained, fine.tune=FALSE), "expected 'rownames(test)' to be the same", fixed=TRUE)
})
