#ifndef SINGLEPP_MARKERS_HPP
#define SINGLEPP_MARKERS_HPP

#include "macros.hpp"

#include <vector>

/**
 * @file Markers.hpp
 *
 * @brief Define the `Markers` typedef.
 */

namespace singlepp {

/**
 * A vector of vectors of ranked marker lists, used to determine which features should be used to compute correlations in `Classifier`.
 *
 * For a `Markers` object `markers`, let us consider the vector at `markers[0][1]`.
 * This vector is expected to contain the ranked indices of the marker genes for label 0 compared to label 1.
 * Most typically, this is generated by identifying the genes that are upregulated in label 0 compared to 1 and sorting by decreasing effect size.
 * Indices should refer to the rows of the reference expression matrices (i.e., `ref` in the various `Classifier::run()` or `BasicBuilder::run()` methods).
 * So, for example, `markers[0][1][0]` should contain the row index of the most upregulated gene in label 0 compared to 1.
 *
 * For a given reference dataset, the corresponding `Markers` object should have length equal to the number of labels in that reference.
 * Each middle vector (i.e., `markers[i]` for non-negative `i` less than the number of labels) should also have length equal to the number of labels.
 * The innermost vectors that are not on the diagonal (i.e., `markers[i][j]` for `i != j`) may be of any positive length and should contain unique row indices.
 * Any innermost vector along the "diagonal" (i.e., `markers[i][i]`) is typically of zero length.
 *
 * Ideally, the non-diagonal innermost vectors should be at least as long as the setting of `Classifier::set_top()`.
 * The cell type annotation will still work with shorter (non-empty) vectors but it will not be possible to achieve the user-specified `set_top()`.
 * In cases involving feature intersections in `run()`, the vectors should be long enough to achieve the specified `set_top()` after removing non-shared genes.
 * For longer vectors, the annotation will safely ignore the indices after the `set_top()` specification.
 *
 * As mentioned previously, the diagonal innermost vectors are typically empty, given that it makes little sense to identify upregulated markers in a label compared to itself.
 * That said, any genes stored on the diagonal will be respected and used in all feature subsets for the corresponding label.
 * This can be exploited by advanced users to efficiently store "universal" markers for a label, i.e., markers that are applicable in all comparisons to other labels.
 */
typedef std::vector<std::vector<std::vector<int> > > Markers;

}

#endif
