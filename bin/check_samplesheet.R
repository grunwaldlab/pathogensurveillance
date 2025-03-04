#!/usr/bin/env Rscript

# This script takes 2 arguments:
#   1. The path to the per-sample CSV input to the pipeline supplied by the user
#   2. The path to the per-reference CSV input to the pipeline supplied by the user
#
# The first part of this script defines constants that might need to be changed in the future.

# Parse inputs
args <- commandArgs(trailingOnly = TRUE)
args <- as.list(args)

# Test data sets (should all be commented out)
args <- list("/home/fosterz/projects/pathogensurveillance/tests/data/metadata/feature_test.tsv", "/home/fosterz/projects/pathogensurveillance/tests/data/metadata/feature_test_refs.csv")




# Lookup SRA runs accessions for biosamples
get_sra_from_biosamples <- function(biosample_id) {
    # Create an empty data frame to store biosample_id to SRA mapping
    sra_data <- data.frame(
        biosample_id = character(),
        SRR = character(),
        stringsAsFactors = FALSE
    )

    message("Processing biosample_id:", biosample_id, "\n")

    # Search for biosample_id in the NCBI database to get its internal ID
    search_result <- tryCatch({
        rentrez::entrez_search(db = "biosample", term = biosample_id)
    }, error = function(e) {
        warning("Error while searching for biosample_id:", biosample_id, "\n")
        return(NULL)
    })

    genbank_id <- search_result$ids[1]

    # Use elink to find linked SRA records
    sra_link_result <- tryCatch({
        rentrez::entrez_link(dbfrom = "biosample", id = genbank_id, db = "sra")
    }, error = function(e) {
        warning("Error while linking biosample_id to SRA:", genbank_id, "\n")
        return(NULL)
    })
    assembly_link_result <- tryCatch({
        rentrez::entrez_link(dbfrom = "biosample", id = genbank_id, db = "assembly")
    }, error = function(e) {
        warning("Error while linking biosample_id to assembly database:", genbank_id, "\n")
        return(NULL)
    })
    sra_id <- sra_link_result$links$biosample_sra
    assembly_id <- assembly_link_result$links$biosample_assembly
    if (is.null(sra_id) && is.null(assembly_id)) {
        warning('No SRA or assembly accessions found for ncbi_accession value: "', biosample_id, '"')
        return(NULL)
    } else if (is.null(sra_id)) {
        warning('No SRA accessions found for ncbi_accession value: "', biosample_id, '". In the future, the assembly may be used instead.')
    }
    if (length(sra_id) > 1) {
        warning('Multiple SRA accessions found for ncbi_accession value: "', biosample_id, '"')
    }
    if (length(assembly_id) > 1) {
        warning('Multiple assembly accessions found for ncbi_accession value: "', biosample_id, '"')
    }

    if (!is.null(sra_id)) {
        # Retrieve detailed information about the SRA run
        sra_record <- tryCatch({
            rentrez::entrez_summary(db = "sra", id = sra_id)
        }, error = function(e) {
            warning("Error retrieving SRA record for:", sra_id, "\n")
            return(NULL)
        })
        # Extract run IDs
        if (!is.null(sra_record)) {
            if (inherits(sra_record, "esummary_list")) {
                run_data <- unname(vapply(sra_record, function(x) x$runs, FUN.VALUE = character(1)))
            } else {
                run_data <- sra_record$runs
            }
            runs <- unlist(strsplit(run_data, split = ";"))
            run_ids <- sub('.*acc="([^"]*)".*', '\\1', runs)
        } else {
            warning("Error retrieving runs for SRA record:", sra_id, "\n")
            return(NULL)
        }
    } else if (!is.null(assembly_id)) {
        # Retrieve detailed information about the SRA run
        assembly_record <- tryCatch({
            rentrez::entrez_summary(db = "assembly", id = assembly_id)
        }, error = function(e) {
            warning("Error retrieving SRA record for:", assembly_id, "\n")
            return(NULL)
        })
        # Extract run IDs
        if (!is.null(assembly_record)) {
            if (inherits(assembly_record, "esummary_list")) {
                run_ids <- unname(vapply(assembly_record, function(x) x$assemblyaccession, FUN.VALUE = character(1)))
            } else {
                run_ids <- assembly_record$assemblyaccession
            }
        } else {
            warning("Error retrieving runs for assembly record:", sra_id, "\n")
            return(NULL)
        }
    }

    return(run_ids)
}
is_biosample_to_lookup <- grepl("^SAM[NDE]", metadata_samp$ncbi_accession) & metadata_samp$enabled
biosample_ids <- unique(metadata_samp$ncbi_accession[is_biosample_to_lookup])
run_id_key <- lapply(biosample_ids, get_sra_from_biosamples)
names(run_id_key) <- biosample_ids

# Report biosamples with no reads to the user
no_runs_found <- names(run_id_key)[vapply(run_id_key, is.null, logical(1))]
if (length(no_runs_found) > 0) {
    warning('The following ', length(no_runs_found), ' biosamples do not have reads associated with them:\n',
            paste0(no_runs_found, collapse = '\n'), '\n')
    message_data <- rbind(message_data, data.frame(
        sample_id = metadata_samp$sample_id[metadata_samp$ncbi_accession %in% no_runs_found],
        report_group_id = metadata_samp$report_group_ids[metadata_samp$ncbi_accession %in% no_runs_found],
        reference_id = NA_character_,
        workflow = 'PREPARE_INPUT',
        message_type = 'WARNING',
        description = 'Sample removed since there are no runs associated with this biosample.'
    ))
    metadata_samp <- metadata_samp[! metadata_samp$ncbi_accession %in% no_runs_found, , drop = FALSE]
}

# Report biosamples with multiple SRA runs associated with them
multiple_runs_found <- names(run_id_key)[vapply(run_id_key, function(x) length(x) > 1, logical(1))]
if (length(multiple_runs_found) > 0) {
    warning('The following ', length(multiple_runs_found), ' biosamples have multiple SRA runs associated with them:\n',
            paste0(multiple_runs_found, collapse = '\n'), '\n')
    message_data <- rbind(message_data, data.frame(
        sample_id = metadata_samp$sample_id[metadata_samp$ncbi_accession %in% multiple_runs_found],
        report_group_id = metadata_samp$report_group_ids[metadata_samp$ncbi_accession %in% multiple_runs_found],
        reference_id = NA_character_,
        workflow = 'PREPARE_INPUT',
        message_type = 'NOTE',
        description = 'Biosample associated with multiple SRA accessions. Sample will be treated as multiple samples, one for each run associated with its biosample. User-defined sequence_type will be ignored.'
    ))
}

# Report biosamples with assemblies associated with them instead of SRA accessions
assembly_found <- names(run_id_key)[vapply(run_id_key, function(x) any(grepl(x, pattern = '^GC[AF]_[0-9]+\\.?[0-9]*$')), FUN.VALUE = logical(1))]
if (length(assembly_found) > 0) {
    warning('The following ', length(assembly_found), ' biosamples are associated with assembly(s) instead of SRA accessions:\n',
            paste0(assembly_found, collapse = '\n'), '\n')
    message_data <- rbind(message_data, data.frame(
        sample_id = metadata_samp$sample_id[metadata_samp$ncbi_accession %in% assembly_found],
        report_group_id = metadata_samp$report_group_ids[metadata_samp$ncbi_accession %in% assembly_found],
        reference_id = NA_character_,
        workflow = 'PREPARE_INPUT',
        message_type = 'WARNING',
        description = 'Biosample associated with assembly(s) instead of SRA accessions. These may be supported as samples in the future, but will be ignored for now.'
    ))
}

# Duplicate rows with multiple SRA accessions for a given biosample
split_metadata <- lapply(seq_len(nrow(metadata_samp)), function(i) {
    current <- metadata_samp$ncbi_accession[i]
    if (current %in% names(run_id_key)) {
        out <- metadata_samp[rep(i, length(run_id_key[[current]])), , drop = FALSE]
        rownames(out) <- NULL
        out$ncbi_accession <- run_id_key[[current]]
        out$sequence_type <- '' # There may be a mix of sequencing types so clear user input to be safe
        if (metadata_samp$enabled[i]) { # Disable biosamples associated with assemblies (for now)
            out$enabled <- ! grepl(run_id_key[[current]], pattern = '^GC[AF]_[0-9]+\\.?[0-9]*$')
        }
    } else {
        out <- metadata_samp[i, , drop = FALSE]
    }
    return(out)
})
metadata_samp <- do.call(rbind, split_metadata)
rownames(metadata_samp) <- NULL




# Ensure sample/reference IDs are present
shared_char <- function(col, end = FALSE) {
    col[col == ''] <- NA_character_
    reverse_char <- function(x) {
        split <- strsplit(x, split = "")
        reversed <- lapply(split, rev)
        return(unlist(lapply(reversed, paste, collapse = "")))
    }
    if (all(is.na(col))) {
        return('')
    }
    shorest_length <- min(unlist(lapply(col, nchar)), na.rm = TRUE)
    result <- ''
    if (end) {
        col <- reverse_char(col)
    }
    indexes <- 1:shorest_length
    for (index in indexes) {
        unique_starts <- unique(substr(col, start = 1, stop = index))
        if (length(unique_starts) == 1) {
            result <- unique_starts
        } else {
            break
        }
    }
    if (end) {
        result <- reverse_char(result)
    }
    return(result)
}

remove_shared <- function(x) {
    if (length(x) > 1) {
        present_x <- x[is_present(x)]
        shared_start <- shared_char(present_x, end = FALSE)
        shared_end <- shared_char(present_x, end = TRUE)
        present_x <- sub(present_x, pattern = paste0('^', shared_start), replacement = '')
        present_x <- sub(present_x, pattern = paste0(shared_end, '$'), replacement = '')
        x[is_present(x)] <- present_x
    } else {
        x = basename(x)
    }
    return(x)
}
remove_file_extensions <- function(x) {
    all_ext_pattern <- paste0('(', paste0(known_extensions, collapse = '|'), ')$')
    all_ext_pattern <- gsub(all_ext_pattern, pattern = '.', replacement = '\\.', fixed = TRUE)
    return(gsub(x, pattern = all_ext_pattern, replacement = ''))
}

reads_ids <- unlist(lapply(1:nrow(metadata_samp), function(row_index) {
    reads_1 <- basename(metadata_samp$path[row_index])
    reads_2 <- basename(metadata_samp$path_2[row_index])
    if (is_present(reads_1) && is_present(reads_2)) {
        remove_different_parts <- function(a, b) {
            a_split <- strsplit(reads_1, split = '')[[1]]
            b_split <- strsplit(reads_2, split = '')[[1]]
            paste0(a_split[a_split == b_split], collapse = '')
        }
        shortread <- remove_different_parts(reads_1, reads_2)
    } else if (is_present(reads_1)) {
        shortread <- reads_1
    } else if (is_present(reads_2)) {
        shortread <- reads_2
    } else {
        shortread <- ''
    }
}))

id_sources_samp <- list( # These are all possible sources of IDs, ordered by preference
    metadata_samp$sample_id,
    metadata_samp$sample_name,
    metadata_samp$ncbi_accession,
    remove_file_extensions(remove_shared(reads_ids))
)
metadata_samp$sample_id <- unlist(lapply(1:nrow(metadata_samp), function(row_index) { # Pick one replacement ID for each sample
    ids <- unlist(lapply(id_sources_samp, `[`, row_index))
    return(ids[is_present(ids)][1])
}))

id_sources_ref <- list( # These are all possible sources of IDs, ordered by preference
    metadata_ref$ref_id,
    metadata_ref$ref_name,
    metadata_ref$ref_ncbi_accession,
    metadata_ref$ref_path
)
if (nrow(metadata_ref) > 0) {
    metadata_ref$ref_id <- unlist(lapply(1:nrow(metadata_ref), function(row_index) { # Pick one replacement ID for each sample
        ids <- unlist(lapply(id_sources_ref, `[`, row_index))
        return(ids[is_present(ids)][1])
    }))
}

# Ensure sample/reference names and descriptions are present
ensure_sample_names <- function(names, ids) {
    unlist(lapply(seq_along(names), function(index) {
        if (is_present(names[index])) {
            return(names[index])
        } else {
            return(ids[index])
        }
    }))
}
metadata_samp$name <- ensure_sample_names(metadata_samp$name, metadata_samp$sample_id)
metadata_samp$description <- ensure_sample_names(metadata_samp$description, metadata_samp$name)
if (nrow(metadata_ref) > 0) {
    metadata_ref$ref_name <- ensure_sample_names(metadata_ref$ref_name, metadata_ref$ref_id)
}
if (nrow(metadata_ref) > 0) {
    metadata_ref$ref_description <- ensure_sample_names(metadata_ref$ref_description, metadata_ref$ref_name)
}






# Ensure that the same sample ID is not used for different sets of data
make_ids_unique <- function(metadata, id_col, other_cols) {
    # Find which IDs need to be changed
    subset <- metadata[, c(id_col, other_cols)]
    subset$row_num <- seq_along(rownames(subset))
    unique_ids <- unique(subset[[id_col]])
    unique_ids <- unique_ids[is_present(unique_ids)]
    id_key <- lapply(unique_ids, function(id) {
        same_id_rows <- subset[subset[[id_col]] == id, ]
        split_by_other <- split(same_id_rows, apply(same_id_rows[, other_cols], 1, paste0, collapse = ''))
        names(split_by_other) <- make.unique(rep(id, length(split_by_other)), sep = '_')
        new_id_key <- lapply(names(split_by_other), function(new_id) { # Get list of data.frames with new IDs and associated row numbers
            data.frame(new_id = new_id, row_num = split_by_other[[new_id]]$row_num)
        })
        new_id_key <- do.call(rbind, new_id_key) # combine list of data.frames to a single one
        return(new_id_key)
    })
    id_key <- do.call(rbind, id_key) # combine list of data.frames to a single one
    # Apply the changes
    metadata[id_key$row_num, id_col] <- id_key$new_id
    return(metadata)
}
metadata_samp <- make_ids_unique(metadata_samp, id_col = 'sample_id', other_cols = c('path', 'path_2', 'ncbi_accession'))
if (nrow(metadata_ref) > 0) {
    metadata_ref <- make_ids_unique(metadata_ref, id_col = 'ref_id', other_cols = c('ref_path', 'ref_ncbi_accession'))
}

# Ensure references and samples do not share ids
is_shared <- metadata_ref$ref_id %in% metadata_samp$sample_id
metadata_ref$ref_id[is_shared] <- paste0(metadata_ref$ref_id[is_shared], '_ref')





# Add reference id to the reference group ids, so that references can be referred to by id even if a group id is not defined.
metadata_ref$ref_group_ids <- ifelse(
    metadata_ref$ref_group_ids == '',
    metadata_ref$ref_id,
    paste(metadata_ref$ref_group_ids, metadata_ref$ref_id, sep = ';')
)





# Check that reference groups in sample metadata are present in the reference metadata
if (nrow(metadata_ref)) {
    all_ref_group_ids <- unique(unlist(strsplit(metadata_ref$ref_group_ids, split = ';')))
    for (index in 1:nrow(metadata_samp)) {
        split_ids <- strsplit(metadata_samp$ref_group_ids[index], split = ';')[[1]]
        invalid_ids <- split_ids[! split_ids %in% all_ref_group_ids]
        if (length(invalid_ids) > 0) {
            stop(call. = FALSE, paste0(
                'The reference group ID "', invalid_ids[1], '" used in row ', index, ' in the sample metadata CSV',
                ' is not defined in the reference metadata CSV. All values in the "ref_group_ids" column in the',
                ' sample metadata CSV must be present in the "ref_group_ids" or "ref_id" columns of the reference',
                ' metadata CSV.'
            ))
        }
    }
}


# Add row for each group for samples/references with multiple groups
duplicate_rows_by_id_list <- function(metadata, id_col) {
    group_ids <- strsplit(metadata[[id_col]], split = ';')
    n_group_ids <- unlist(lapply(group_ids, length))
    group_ids[n_group_ids == 0] <- ''
    n_group_ids <- unlist(lapply(group_ids, length))
    metadata <- metadata[rep(1:nrow(metadata), n_group_ids), ]
    metadata[[id_col]] <- unlist(group_ids)
    rownames(metadata) <- NULL
    return(metadata)
}
metadata_samp <- duplicate_rows_by_id_list(metadata_samp, 'report_group_ids')
if (nrow(metadata_ref) > 0) {
    metadata_ref <- duplicate_rows_by_id_list(metadata_ref, 'ref_group_ids')
}

# Convert reference groups to reference ids in the sample data
metadata_samp$ref_ids <- unlist(lapply(metadata_samp$ref_group_ids, function(group_ids) {
    ref_ids <- metadata_ref$ref_id[metadata_ref$ref_group_ids %in% strsplit(group_ids, split = ';')]
    paste(ref_ids, collapse = ';')
}))


# Remove unneeded columns
metadata_samp$ref_group_ids <- NULL
metadata_samp$ref_id <- NULL
metadata_samp$ref_name <- NULL
metadata_samp$ref_description <- NULL
metadata_samp$ref_path <- NULL
metadata_samp$ref_ncbi_accession <- NULL
metadata_samp$ref_ncbi_query <- NULL
metadata_samp$ref_ncbi_query_max <- NULL
metadata_samp$ref_primary_usage <- NULL
metadata_samp$ref_color_by <- NULL
metadata_ref$ref_group_ids <- NULL

# Make rows unique
metadata_samp <- unique(metadata_samp)
if (nrow(metadata_ref) > 0) {
    metadata_ref <- unique(metadata_ref)
}

# Replace double quotes with single quotes to not conflict with the CSV format quoting values
metadata_samp[] <- lapply(metadata_samp, gsub, pattern = '"', replacement = "'")
metadata_ref[] <- lapply(metadata_ref, gsub, pattern = '"', replacement = "'")
message_data[] <- lapply(message_data, gsub, pattern = '"', replacement = "'")

# Write data for messages to be shown to the user, such as warnings about removed samples
write.table(message_data, file = message_data_path, row.names = FALSE, na = '', sep = '\t')

# Write output metadata
write.table(metadata_samp, file = sample_data_path, row.names = FALSE, na = '', sep = '\t')
write.table(metadata_ref, file = reference_data_path, row.names = FALSE, na = '', sep = '\t')
