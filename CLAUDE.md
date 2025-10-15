# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Nextflow pipeline built using the nf-core template (v3.3.2) for ChIP-seq/ChEC-seq peak calling from BAM files using HOMER (Hypergeometric Optimization of Motif EnRichment). The pipeline processes aligned sequencing data through BAM filtering, tag directory creation, peak calling, and optional peak merging/annotation.

**Pipeline author**: cmatkhan
**Nextflow version requirement**: >=24.10.5
**Repository type**: Independent pipeline (not an official nf-core pipeline)

## Key Commands

### Running the pipeline

```bash
# Basic run with required parameters
nextflow run cmatkhan/homer_peakcalling_from_bam \
  -profile docker \
  --input samplesheet.csv \
  --outdir <OUTDIR>

# Resume a previous run
nextflow run cmatkhan/homer_peakcalling_from_bam \
  -profile docker \
  --input samplesheet.csv \
  --outdir <OUTDIR> \
  -resume

# Run with specific profile configurations
nextflow run cmatkhan/homer_peakcalling_from_bam \
  -profile chipexo,docker \
  --input samplesheet.csv \
  --outdir <OUTDIR>

nextflow run cmatkhan/homer_peakcalling_from_bam \
  -profile chec,docker \
  --input samplesheet.csv \
  --outdir <OUTDIR>

# Run test profile
nextflow run cmatkhan/homer_peakcalling_from_bam \
  -profile test,docker \
  --outdir <OUTDIR>
```

### Testing

```bash
# Run nf-test for specific modules or workflows
nf-test test tests/default.nf.test

# Test specific subworkflow
nf-test test subworkflows/local/homer_peakcalling/tests/main.nf.test
```

### Linting and validation

```bash
# Run pre-commit checks (requires pre-commit installation)
pre-commit run --all-files

# Update cached pipeline
nextflow pull cmatkhan/homer_peakcalling_from_bam
```

## Architecture

### Main Workflow Structure

The pipeline follows nf-core DSL2 conventions with clear separation between:

1. **Main entry point** ([main.nf](main.nf)):
   - `CMATKHAN_HOMER_PEAKCALLING_FROM_BAM` - Main workflow that orchestrates the pipeline
   - Uses `PIPELINE_INITIALISATION` and `PIPELINE_COMPLETION` subworkflows from nf-core utilities

2. **Primary workflow** ([workflows/homer_peakcalling_from_bam.nf](workflows/homer_peakcalling_from_bam.nf)):
   - Takes channels for BAM files, reference genome (FASTA), GTF annotation, optional control BAM, and optional blacklist BED
   - Filters BAMs with `SAMTOOLS_VIEW` (removes duplicates, applies quality filtering)
   - Optionally removes blacklisted regions with `BEDTOOLS_INTERSECT`
   - Calls the `HOMER_PEAKCALLING` subworkflow
   - Generates MultiQC report

3. **HOMER peak calling subworkflow** ([subworkflows/local/homer_peakcalling/main.nf](subworkflows/local/homer_peakcalling/main.nf)):
   - Creates tag directories from BAM files (or accepts pre-made tag directories)
   - Optionally creates bedGraph files for UCSC visualization
   - Calls peaks with `HOMER_FINDPEAKS` (with or without control)
   - Converts peaks to BED format
   - Optionally annotates individual peak files
   - Optionally merges peaks across samples and creates count matrix for differential analysis

### Module Organization

- **nf-core modules** ([modules/nf-core/](modules/nf-core/)): Standard modules from nf-core (samtools, bedtools, multiqc, etc.)
- **Local HOMER modules** ([modules/local/homer/](modules/local/homer/)): Custom modules for HOMER tools
  - `maketagdirectory` - Creates tag directories from BAM/SAM/BED files
  - `findpeaks` - Peak calling with various styles (factor, histone, groseq, tss, dnase, super, mC)
  - `pos2bed` - Converts HOMER peak format to BED
  - `makeucscfile` - Creates bedGraph files for visualization
  - `mergepeaks` - Merges peaks across multiple samples
  - `annotatepeaks` - Annotates peaks with genomic features

### Configuration Profiles

The pipeline uses profile-based configuration for different experimental types:

- **chipexo** ([conf/chipexo.config](conf/chipexo.config)): ChIP-exo specific parameters
  - Uses `-single` flag and `-fragLength 1` for tag directories (5' end only)
  - Tighter peak calling parameters (`-minDist 50`, `-L 1.5`, `-P 0.1`, `-fdr 0.05`)

- **chec** ([conf/chec.conf](conf/chec.conf)): ChEC-seq specific parameters
  - Fragment length of 1 bp, `-C 0` to disable clonal filtering for MNase experiments
  - Uses `-F 4` (4-fold control enrichment) and relaxed p-values

- **base** ([conf/base.config](conf/base.config)): Default resource allocations
  - Process labels: `process_single`, `process_low`, `process_medium`, `process_high`, `process_long`, `process_high_memory`
  - Automatic retry with increased resources on specific error codes

- **modules** ([conf/modules.config](conf/modules.config)): Per-module configuration
  - Controls publish directories and module-specific arguments
  - Overrides with `ext.args`, `ext.args2`, `ext.args3`, `ext.prefix`

### Input/Output

**Input samplesheet format** (CSV):
```csv
sample,bam
SAMPLE1,/path/to/sample1.bam
SAMPLE2,/path/to/sample2.bam
```

**Key parameters**:
- `--input`: Path to samplesheet CSV
- `--outdir`: Output directory
- `--fasta`: Reference genome FASTA (required)
- `--gtf`: Gene annotation GTF (optional, required for annotation)
- `--control_bam`: Control/input BAM file (optional)
- `--blacklist_bed`: Blacklist regions BED file (optional)
- `--merge_peaks`: Boolean to merge peaks across samples (default: false)
- `--annotate_individual`: Boolean to annotate individual peak files (default: false)
- `--quantify_peaks`: Boolean to create count matrix from merged peaks (default: false)
- `--make_bedgraph`: Boolean to create bedGraph visualization files (default: false)

**Output structure**:
```
outdir/
├── homer/
│   └── tagdir/          # Tag directories for each sample
├── findpeaks/           # Individual peak files (.txt and .bed)
├── mergepeaks/          # Merged peaks (if --merge_peaks)
├── annotatepeaks/       # Annotated peaks (if --annotate_individual or merge)
├── multiqc/             # MultiQC report
└── pipeline_info/       # Execution reports and software versions
```

## Development Notes

### Adding New Modules

When adding nf-core modules, use nf-core tools:
```bash
nf-core modules install <module_name>
```

For local modules, follow the structure in `modules/local/homer/` with:
- `main.nf` - Module definition
- `meta.yml` - Module metadata
- `environment.yml` - Conda environment (if applicable)

### Modifying HOMER Parameters

HOMER-specific parameters are controlled via process selectors in profile configs. Use patterns like:
```groovy
withName: '.*:HOMER_FINDPEAKS.*' {
    ext.args = [
        '-L 2',
        '-P 0.001'
    ].join(' ')
}
```

### Channel Handling

The pipeline uses standard Nextflow DSL2 patterns:
- Channels are typed as `[ meta, file ]` tuples where `meta` is a map with sample information
- Control BAMs are converted to a special `[[id: 'realControl'], file]` format
- Empty optional inputs should be `[]` or `Channel.empty()`

### Testing Strategy

The pipeline uses nf-test framework. Test files are located in:
- `tests/` - Pipeline-level tests
- `subworkflows/*/tests/` - Subworkflow tests
- Per-module tests are possible but not currently implemented

### Known Issues

- Control tag directory handling assumes single control (not generalized for multiple controls)
- The `HOMER_ANNOTATEPEAKS` functionality is partially commented out in the main workflow
