# Citing ultimaC4walker

If you use **ultimaC4walker** in your research, please cite it. A machine-readable
[`CITATION.cff`](CITATION.cff) is also provided (GitHub renders a "Cite this
repository" button from it).

## Software

> Bareke, E., M., Ethan, & B., Conrad (2026). *ultimaC4walker: a multi-runtime
> workflow for ChIP-seq, CUT&RUN, CUT&Tag and ATAC-seq* (Version 1.0.0)
> [Computer software]. https://github.com/ebareke/ultimaC4walker

## BibTeX

```bibtex
@software{ultimaC4walker_2026,
  author  = {Bareke, Eric and M., Ethan and B., Conrad},
  title   = {{ultimaC4walker: a multi-runtime workflow for ChIP-seq,
             CUT\&RUN, CUT\&Tag and ATAC-seq}},
  year    = {2026},
  version = {1.0.0},
  license = {MIT},
  url     = {https://github.com/ebareke/ultimaC4walker},
  note    = {Documentation: https://ebareke.github.io/ultimaC4walker/}
}
```

## APA

> Bareke, E., M., E., & B., C. (2026). *ultimaC4walker: a multi-runtime workflow
> for ChIP-seq, CUT&RUN, CUT&Tag and ATAC-seq* (Version 1.0.0) [Computer
> software]. https://github.com/ebareke/ultimaC4walker

## Please also cite the underlying tools

ultimaC4walker orchestrates established tools; cite the ones your run used:

| Tool | Use in the workflow |
|------|---------------------|
| **BWA** (Li & Durbin, 2009) | Read alignment |
| **SAMtools** (Danecek *et al.*, 2021) | BAM filtering, dedup, stats |
| **BEDTools** (Quinlan & Hall, 2010) | Blacklist subtraction, FRiP |
| **MACS3 / MACS2** (Zhang *et al.*, 2008) | Peak calling |
| **deepTools** (Ramírez *et al.*, 2016) | bigWig coverage, fragment size |
| **Picard** (Broad Institute) | Duplication metrics |
| **preseq** (Daley & Smith, 2013) | Library-complexity estimation |
| **phantompeakqualtools** (Landt *et al.*, 2012; Kharchenko *et al.*, 2008) | NSC / RSC cross-correlation |
| **FastQC** (Andrews, 2010) | Read-level QC |
| **MultiQC** (Ewels *et al.*, 2016) | Aggregate report |
| **Nextflow** (Di Tommaso *et al.*, 2017) | Pipeline execution (Nextflow mode) |

## Version

This citation refers to **v1.0.0**. For a specific version, cite the matching
release tag at <https://github.com/ebareke/ultimaC4walker/releases>.

## Authors

- **Eric Bareke** — <eb.bioinfo@pm.me>
- **Ethan M.** — <eb.bioinfo@pm.me>
- **Conrad B.** — <eb.bioinfo@pm.me>
