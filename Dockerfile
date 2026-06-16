# syntax=docker/dockerfile:1
#
# ultimaC4walker — production container.
#
# A single micromamba image bundling the c4walker tool plus the entire
# bioinformatics toolchain (bwa, samtools, bedtools, MACS2, FastQC, Picard,
# preseq, deepTools, phantompeakqualtools, MultiQC), so one container runs the
# complete FASTQ -> peaks/QC workflow for ChIP-seq / CUT&RUN / CUT&Tag / ATAC.
#
#   docker build -t ultimac4walker:1.0.0 .
#   docker run --rm -v "$PWD":/data ultimac4walker:1.0.0 \
#       run -c /data/config.yaml -s /data/samples.tsv
#
# ---------------------------------------------------------------------------
FROM mambaorg/micromamba:1.5-jammy

LABEL org.opencontainers.image.title="ultimaC4walker" \
      org.opencontainers.image.description="Chromatin-profiling workflow — ChIP-seq, CUT&RUN, CUT&Tag, ATAC-seq" \
      org.opencontainers.image.source="https://github.com/ebareke/ultimaC4walker" \
      org.opencontainers.image.url="https://ebareke.github.io/ultimaC4walker/" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="1.0.0"

ARG MAMBA_DOCKERFILE_ACTIVATE=1
USER root

# Bioinformatics toolchain (pinned) via bioconda.
COPY environment.yml /tmp/environment.yml
RUN micromamba install -y -n base -f /tmp/environment.yml \
    && micromamba clean --all --yes

# Install the c4walker tool (binary entrypoint + sourced libraries).
COPY bin/ /opt/c4walker/bin/
COPY lib/ /opt/c4walker/lib/
RUN chmod +x /opt/c4walker/bin/c4walker \
    && ln -s /opt/c4walker/bin/c4walker /usr/local/bin/c4walker

ENV PATH=/opt/conda/bin:$PATH \
    C4_LIBDIR=/opt/c4walker/lib \
    PHANTOMPEAK_RSCRIPT=/opt/conda/bin/run_spp.R
WORKDIR /data

# Build-time self-check.
RUN c4walker version

ENTRYPOINT ["c4walker"]
CMD ["help"]
