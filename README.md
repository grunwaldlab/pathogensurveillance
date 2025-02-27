<h1>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/nf-core-pathogensurveillance_logo_dark.png">
    <img alt="nf-core/pathogensurveillance" src="docs/images/nf-core-pathogensurveillance_logo_light.png">
  </picture>
</h1>

[![GitHub Actions CI Status](https://github.com/nf-core/pathogensurveillance/actions/workflows/ci.yml/badge.svg)](https://github.com/nf-core/pathogensurveillance/actions/workflows/ci.yml)
[![GitHub Actions Linting Status](https://github.com/nf-core/pathogensurveillance/actions/workflows/linting.yml/badge.svg)](https://github.com/nf-core/pathogensurveillance/actions/workflows/linting.yml)[![AWS CI](https://img.shields.io/badge/CI%20tests-full%20size-FF9900?labelColor=000000&logo=Amazon%20AWS)](https://nf-co.re/pathogensurveillance/results)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A524.04.2-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://cloud.seqera.io/launch?pipeline=https://github.com/nf-core/pathogensurveillance)

[![Get help on Slack](http://img.shields.io/badge/slack-nf--core%20%23pathogensurveillance-4A154B?labelColor=000000&logo=slack)](https://nfcore.slack.com/channels/pathogensurveillance)[![Follow on Twitter](http://img.shields.io/badge/twitter-%40nf__core-1DA1F2?labelColor=000000&logo=twitter)](https://twitter.com/nf_core)[![Follow on Mastodon](https://img.shields.io/badge/mastodon-nf__core-6364ff?labelColor=FFFFFF&logo=mastodon)](https://mstdn.science/@nf_core)[![Watch on YouTube](http://img.shields.io/badge/youtube-nf--core-FF0000?labelColor=000000&logo=youtube)](https://www.youtube.com/c/nf-core)

## Introduction

**nf-core/pathogensurveillance** is a population genomic pipeline for pathogen diagnosis, variant detection, and biosurveillance.
The pipeline accepts the paths to raw reads for one or more organisms (in the form of a TSV or CSV file) and creates reports in the form of interactive HTML reports or PDF documents.
Significant features include the ability to analyze unidentified eukaryotic and prokaryotic samples, creation of reports for multiple user-defined groupings of samples, automated discovery and downloading of reference assemblies from NCBI RefSeq, and rapid initial identification based on k-mer sketches followed by a more robust core genome phylogeny and SNP-based phylogeny.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner.
It uses Docker/Singularity containers making installation trivial and results highly reproducible.
The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies.
Where possible, these processes have been submitted to and installed from [nf-core/modules](https://github.com/nf-core/modules) in order to make them available to all nf-core pipelines, and to everyone within the Nextflow community!

<!-- TODO nf-core: Add full-sized test dataset and amend the paragraph below if applicable -->

On release, automated continuous integration tests run the pipeline on a full-sized dataset on the AWS cloud infrastructure.
This ensures that the pipeline runs on AWS, has sensible resource allocation defaults set to run on real-world data sets, and permits the persistent storage of results to benchmark between pipeline releases and other analysis sources.The results obtained from the full-sized test can be viewed on the [nf-core website](https://nf-co.re/pathogensurveillance/results).

## Pipeline summary

![Pipeline flowchart](docs/posters/pipeline_diagram.png)

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

First, prepare a samplesheet with your input data that looks as follows:

```bash
nextflow run nf-core/pathogensurveillance -r dev -profile RUN_TOOL,xanthomonas_small -resume --out_dir test_output
```

Note that some form of configuration will be needed so that Nextflow knows how to fetch the required software. This is usually done in the form of a config profile (`RUN_TOOL` in the example command above). You can chain multiple config profiles in a comma-separated string.

> - The pipeline comes with config profiles called `docker`, `singularity`, `podman`, `shifter`, `charliecloud` and `conda` which instruct the pipeline to use the named tool for software management. For example, `-profile xanthomonas_small,docker`.
> - Please check [nf-core/configs](https://github.com/nf-core/configs#documentation) to see if a custom config file to run nf-core pipelines already exists for your Institute. If so, you can simply use `-profile <institute>` in your command. This will enable either `docker` or `singularity` and set the appropriate execution settings for your local compute environment.
> - If you are using `singularity`, please use the [`nf-core download`](https://nf-co.re/tools/#downloading-pipelines-for-offline-use) command to download images first, before running the pipeline. Setting the [`NXF_SINGULARITY_CACHEDIR` or `singularity.cacheDir`](https://www.nextflow.io/docs/latest/singularity.html?#singularity-docker-hub) Nextflow options enables you to store and re-use the images from a central location for future pipeline runs.
> - If you are using `conda`, it is highly recommended to use the [`NXF_CONDA_CACHEDIR` or `conda.cacheDir`](https://www.nextflow.io/docs/latest/conda.html) settings to store the environments in a central location for future pipeline runs.

-->

Now, you can run the pipeline using:

```bash
nextflow run nf-core/pathogensurveillance -r dev -profile RUN_TOOL -resume --sample_data <TSV/CSV> --out_dir <OUTDIR> --download_bakta_db
```

```bash
nextflow run nf-core/pathogensurveillance \
   -profile <docker/singularity/.../institute> \
   --input samplesheet.tsv \
   --outdir <OUTDIR>
```

## Documentation

For more details and further functionality, please refer to the [usage documentation](https://nf-co.re/pathogensurveillance/usage) and the [parameter documentation](https://nf-co.re/pathogensurveillance/parameters).

Documentation is currently under development, but can be found here:

https://grunwaldlab.github.io/pathogensurveillance_documentation

### Input format

The primary input to the pipeline is one or more TSV (tab-separated value) or CSV (comma comma-separated value) file, specified using the `--input` option.
These can be made in a spreadsheet program like [LibreOffice Calc](https://www.libreoffice.org/) or Microsoft Excel by exporting to TSV/CSV.
Each of these input tables have the same input format requirements, but different types of data can be stored in different inputs for the user's convenience, see the "Using multiple input tables" section below for more details.

#### Format flexiblity

Columns can be in any order and unused columns can be left out or left blank.
Column names and values for categorical columns (e.g. `type`) are case insensitive and spaces and dashes are equivalent to underscores.
Any columns not recognized by `pathogensurveillance` will be ignored, allowing users to adapt existing sample metadata tables by adding or renaming columns.

#### Required and recommended columns

This pipeline is designed to be useful with minimal inputs while still being very flexible for advanced users.
Only the `type` and `source` columns are needed, but you probably want the following columns as well:

- `data_id`, `bio_id`, and `report_id`: so output files have nice names
- `name` and `description`: so figures have nice labels
- `ploidy`: to avoid errors when using diploids
- `color_by`: so figures have colors relevant to the user's use case

#### All recognized columns

Below is a description of each column used by `pathogensurveillance`:

- **`data_id`**: The unique identifier for each combination of `type` and `source`.
    This ID can appear in multiple tables or rows as long as only one of those instances has values for the `type` and `source` columns and no other columns have overlapping values.
    When it appears in multiple tables/rows, the data is combined into a single row.
    This will be used to name output files where relevant, so any values supplied that that cannot appear in file names (\/:\*?"<>| .) will be modified automatically.
    Note that changing this ID after the pipeline has already been run will invalidate the cache associated with this data.
    It might therefore be preferable in some cases to not set this manually and allow the pipeline to use a hash of the `type` and `source` columns, which is the default behavior.
- **`bio_id`**: The unique identifier for the organism or physical sample the data on this row is associated with.
    Multiple rows can share this ID to indicate that multiple data are associated with this same sample.
    For example, Illumina reads from an isolate and photos of the same isolate growing on a plate.
    This will be used to name output files where relevant, so any values supplied that that cannot appear in file names (\/:\*?"<>| .) will be modified automatically.
    If not supplied, it will based on the `data_id` column value.
- **`report_id`**: How to group samples into reports.
    A report will be generated for every unique value in this column.
    Samples can be assigned to multiple reports by separating group IDs by `;`.
    For example `all;subset` will put the sample in both `all` and `subset` reports.
    This will be used to name output files where relevant, so any values supplied that that cannot appear in file names (\/:\*?"<>| .) will be modified automatically.
    If not supplied, samples will be added to a report with the ID `miscellaneous`.
- **`usage`**: Controls how the pipeline uses this input, particularly whether the input is a "sample" that should be identified and tracked or a "reference" that should be used when useful to provide context to samples. Can accept the following values:
    - `sample` (default): These are inputs you want more information about. The pipeline will analyze the data in `type` and `source` as well as any metadata available in other columns to try to identify and analyze the sample.
    - `reference`: These are "known" inputs. The pipeline will use the data in `type` and `source` as well as any metadata available in other columns to provide context to samples or aid in the analysis of sample data.
    - `sample metadata`: Like `sample`, but only metadata such as `location` and `time` will be used.
    - `reference metadata`: Like `reference`, but only metadata such as `location` and `time` will be used.
- **`name`**: A short human-readable label that is used in plots and tables.
    If not supplied, it will be inferred from `description` or `bio_id`.
- **`description`**: A longer human-readable label that is used in plots and tables.
    If not supplied, it will be inferred from `name` or `bio_id`.
- **`enabled`**: Either `TRUE` or `FALSE`, indicating whether the sample should be included in the analysis or not. Defaults to `TRUE`.
- **`type`**: What the type of the data in `source` is. Can be any of the following:
    - `Illumina`: Illumina sequence data reads supplied as file paths to local FASTQ files or URLs. The two files from paired end sequencing can be defined by separating their paths with `;`.
    - `Nanopore`: Nanopore sequence data reads supplied as file paths to local FASTQ files or URLs. 
    - `Pacbio`: Pacbio sequence data reads supplied as file paths to local FASTQ files or URLs.
    - `Assembly`: Genome assemblies 
    - `NCBI accession`: A SRA, assembly, or biosample accession.
    - `NCBI SRA query`: A query to the NCBI Short Read Archive (SRA). All values matching the query will be downloaded and used. Beware, this can be an impractical amount of results. The maximum number of values returned can be controlled with the `query_max` column.
    - `NCBI assembly query`: A query to the NCBI assembly database. All values matching the query will be downloaded and used. Beware, this can be an impractical amount of results. The maximum number of values returned can be controlled with the `query_max` column.
    - `image`: A photograph or other image.
    - `observation`: The description or name of something that was observed. Primarily a way to have metadata about something, like it location or data, without any other type of input.
- **`source`**: The value identifying the data to be used, such as file paths, URLs, or database IDs, as defined by the `type` column.
- **`query_max`**: The maximum number, proportion, or percentage of results to use from input types that use database searches such as `NCBI SRA query` and `NCBI assembly query`.
    If not supplied, defaults to `10`.
- **`reference`**: Specifies which references are associated with this data.
    can be one or more values from the `data_id`, `bio_id`, or `ref_group_id` columns separated by ";".
    If not supplied, only references that share the same `report_id` will be considered.
- **`ref_group_id`**: One or more reference group IDs separated by ";".
    These indicate which reference group a reference is a part of, allowing multiple references to be specified using a single ID in the `references` column.
- **`ref_primary_usage`**: Controls how the reference is used in cases where a single "best" reference is required, such as for variant calling. Can be one of:
    - `optional`: Can be used if selected by the pipeline
    - `required`: Will always be used if possible
    - `exclusive`: Only those marked "exclusive" will be used
    - `excluded`: Will not be used
- **`ref_contextual_usage`**: Controls how the reference is used in cases where multiple references are required to provide context for the samples, such as for phylogeny. Can be one of:
    - `optional`: Can be used if selected by the pipeline
    - `required`: Will always be used if possible
    - `exclusive`: Only those marked "exclusive" will be used
    - `excluded`: Will not be used
- **`color_by`**: The names of other columns, usually user-specific, that contain values used to color samples in plots and figures in the report.
    Multiple column names can be separated by ";".
    Specified columns can contain either categorical factors or specific colors, specified as a hex code.
    By default, samples will be one color and references another.
- **`ploidy`**: The ploidy of the sample. Should be a number. Defaults to `1` (haploid).
- **`latitude`**: The latitude associated with a sample in decimal degrees (e.g. `40.446`).
- **`longitude`**: The longitude associated with a sample in decimal degrees (e.g. `-79.982`).
- **`location`**: An address, place name of a geographical location, or coordinates associated with the sample.
    Address components should be separated by commas and can contain arbitrary numbers of components (e.g. 'street, city/town, county, state, region, country' or 'city, state, country' or just 'country').
    Used to infer values for the `latitude` and `longitude` columns if they are not supplied.
    If `latitude` and `longitude` are supplied, the value of this column will be inferred.
- **`country`**: The country a sample was found in.
- **`region`**: The part of a country a sample was found in, for example a state in the United States.
- **`subregion`**: A smaller region within a larger region of a country, for example a county in the United States.
- **`place`**: A city, town, village, park, or other notable point.
- **`part`**: A part of a `place`, such as a neighborhood, road, or city district.
- **`date`**: The date and optionally time associated with an input.
    Used to populate the `year`, `month`, `day`, `hour`, `minute`, and `second` columns if not supplied.
    Smaller time increments, such as seconds, can be omitted but large time increments must be present if smaller time increments are present.
    The year component of dates must include 4 digits (for example `2024`).
    For example, `March 21` would not be valid since it does not include the year.
    Most common data/time formats are supported.
- **`year`**: The year with 4 digits (For example `2024`)
- **`month`**: The month of year, either a number, abbreviation, or full name.
- **`day`**: The day of the month as a number.
- **`hour`**: The hour of a 24 hour clock or a 12 hour clock with am/pm (For example `13` and `1pm` are the same)
- **`minute`**: The minute of an hour, between 0 and 60.
- **`second`**: The seconds in an hour, between 0 and 60.
- **`link`**: One or more URLs associated with the input, separated by `;`.

#### Disallowed columns

There are also a few columns that the pipeline uses internally and these **cannot be supplied by the user**:

- **`_row_index_`**: Used to store the original row an input was on, primarily for error reporting.
- **`_input_path_`**: Used to store the original file an input was from, primarily for error reporting.
- **`_sheet_name_`**: Used to store which sheet in spreadsheet style inputs a value came from.

#### Using multiple input tables

Multiple input tables are supported.
All input tables are combined into a single table as a first step in the pipeline, but each input table can have different subsets of supported columns or user-specific custom columns.
This can be useful if you are adapting multiple existing tables or want to have separate tables for different types of data.
Here are some examples:

- One table contains paths to sequence data using `Illumina` input types while another has GPS coordinates of where that organism was found using `observation` input types.
    In this case the two tables would need a `bio_id` column with values identifying which sequence data set goes with which GPS coordinates.
- One table contains samples with `sample` in the `usage` column and another has references with `reference` in the `usage` column.
- Storing the location associated with `assembly` data types in a separate table by using the same values in the `data_id` column.

In all cases, having multiple tables is the same as having the same data as different rows in the same table.


## Credits

nf-core/pathogensurveillance was originally written by Zachary S.L. Foster, Camilo Parada-Rojas, Logan Blair, Martha Sudermann, Nicholas C. Cauldron, Fernanda I. Bocardo, Ricardo Alcalá-Briseño, Hung Phan, Jeﬀ H. Chang, Niklaus J. Grünwald

To see the results of an example test run with a full size dataset refer to the [results](https://nf-co.re/pathogensurveillance/results) tab on the nf-core website pipeline page.
For more details about the output files and reports, please refer to the
[output documentation](https://nf-co.re/pathogensurveillance/output).

## Credits

nf-core/pathogensurveillance was originally written by Zachary S.L. Foster, Martha Sudermann, Nicholas C. Cauldron, Fernanda I. Bocardo, Hung Phan, Jeﬀ H. Chang, Niklaus J. Grünwald.

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on the [Slack `#pathogensurveillance` channel](https://nfcore.slack.com/channels/pathogensurveillance) (you can join with [this invite](https://nf-co.re/join/slack)).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use nf-core/pathogensurveillance for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
