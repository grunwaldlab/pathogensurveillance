#!/usr/bin/env Rscript

# MIT License
#
# Copyright (c) Zachary S.L. Foster and Niklaus J. Grunwald
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Load dependencies
library(rentrez)

# Options
ani_threshold <- c(species = 95, genus = 90, family = 70)  # These numbers are total guesses. TODO: find reasonable defaults (issue #11)
complt_threshold <- c(species = 40, genus = 15, family = 5) # These numbers are total guesses. TODO: find reasonable defaults (issue #11)

# Parse inputs
args <- commandArgs(trailingOnly = TRUE)
# args <- list('~/projects/pathogensurveillance/work/57/16704de16a603b86e9c2220afc64a1/LF1.txt')
sendsketch_data <- read.csv(args[[1]], skip = 2, header = TRUE, sep = '\t')

# Format table
sendsketch_data$ANI <- as.numeric(sub(pattern = "%", replacement = "", fixed = TRUE, sendsketch_data$ANI))
sendsketch_data$Complt <- as.numeric(sub(pattern = "%", replacement = "", fixed = TRUE, sendsketch_data$Complt))

# Look up taxonomy based on taxon ID for most up to date taxonomy
raw_xml = entrez_fetch(db = 'taxonomy', id = sendsketch_data$TaxID, rettype = 'xml')
get_capture_group <- function(x, pattern) {
    matches <- regmatches(x, gregexpr(pattern, x))[[1]]
    sub(matches, pattern = pattern, replacement = '\\1')
}
class_xml <- get_capture_group(raw_xml, '<LineageEx>(.+?)</LineageEx>')
class_names <- lapply(class_xml, get_capture_group, pattern = '<ScientificName>(.+?)</ScientificName>')
class_ranks <- lapply(class_xml, get_capture_group, pattern = '<Rank>(.+?)</Rank>')
class_ids <- lapply(class_xml, get_capture_group, pattern = '<TaxId>(.+?)</TaxId>')
tip_taxon_ids <- get_capture_group(raw_xml, '<Taxon>\n    <TaxId>(.+?)</TaxId>')
class_data <- data.frame(
    tip_taxon_id = rep(tip_taxon_ids, sapply(class_names, length)),
    taxon_id = unlist(class_ids),
    name = unlist(class_names),
    rank = unlist(class_ranks)
)
class_data <- unique(class_data)
# class_data$classification <- unlist(lapply(split(class_data, class_data$tip_taxon_id), function(part) {
#     vapply(seq_len(nrow(part)), FUN.VALUE = character(1), function(i) {
#         paste0(part$name[1:i], collapse = ';')
#     })
# }))


# Filter data by threshold and extract passing taxon names
filter_and_extract <- function(rank) {
    subset_ids <- sendsketch_data$TaxID[sendsketch_data$ANI > ani_threshold[rank] & sendsketch_data$Complt > complt_threshold[rank]]
    subset_class_data <- class_data[class_data$tip_taxon_id %in% subset_ids & class_data$rank == rank, , drop = FALSE]
    subset_class_data[, c('taxon_id', 'name', 'rank'), drop = FALSE]
}

# Extract taxon info
output_data <- unique(do.call(rbind, lapply(names(ani_threshold), filter_and_extract)))

# Write table of taxon "found"
write.table(output_data, file = 'taxa_found.tsv', sep = '\t', col.names = TRUE, row.names = FALSE, quote = FALSE)

# Write table of all taxon information
write.table(class_data, file = 'taxon_data.tsv', sep = '\t', col.names = TRUE, row.names = FALSE, quote = FALSE)

# Save domain
domain <- class_data$name[class_data$tip_taxon_id == sendsketch_data$TaxID[1] & class_data$rank == 'domain']
writeLines(domain, "domain.txt")
