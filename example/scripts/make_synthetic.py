#!/usr/bin/env python3
"""Generate a tiny synthetic chromatin dataset for ultimaC4walker.

Creates, under example/data/:
  reference.fa        a small 2-contig genome (~10 kb)
  *.fastq.gz          paired-end reads for two samples, enriched over a
                      "peak" window so MACS2 has something real to call
  samples.tsv         standalone-tool sample sheet
  samplesheet.csv     Nextflow sample sheet

Pure standard library (random, gzip) — no numpy / pysam needed. Deterministic
via a fixed seed, so the example reproduces byte-for-byte.
"""
import gzip
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.normpath(os.path.join(HERE, "..", "data"))
random.seed(42)

CHROMS = {"chr1": 6000, "chr2": 4000}
PEAKS = {"chr1": (2500, 3000), "chr2": (1500, 1900)}  # enriched windows
READLEN = 50
BASES = "ACGT"


def random_seq(n):
    return "".join(random.choice(BASES) for _ in range(n))


def write_reference(genome):
    path = os.path.join(DATA, "reference.fa")
    with open(path, "w") as fh:
        for name, seq in genome.items():
            fh.write(">%s\n" % name)
            for i in range(0, len(seq), 70):
                fh.write(seq[i:i + 70] + "\n")
    return path


def revcomp(s):
    return s.translate(str.maketrans("ACGT", "TGCA"))[::-1]


def sample_reads(genome, n_pairs, frag=200):
    """Yield (r1, r2) fragments, oversampling the peak windows ~8x."""
    chroms = list(genome)
    for _ in range(n_pairs):
        c = random.choice(chroms)
        seq = genome[c]
        if random.random() < 0.66:  # enrich the peak region
            lo, hi = PEAKS[c]
            start = random.randint(max(0, lo - frag), max(0, hi - frag))
        else:
            start = random.randint(0, len(seq) - frag - 1)
        fragment = seq[start:start + frag]
        r1 = fragment[:READLEN]
        r2 = revcomp(fragment[-READLEN:])
        yield r1, r2


def write_fastq_pair(sample, genome, n_pairs):
    p1 = os.path.join(DATA, "%s_R1.fastq.gz" % sample)
    p2 = os.path.join(DATA, "%s_R2.fastq.gz" % sample)
    qual = "I" * READLEN
    with gzip.open(p1, "wt") as f1, gzip.open(p2, "wt") as f2:
        for i, (r1, r2) in enumerate(sample_reads(genome, n_pairs)):
            f1.write("@%s.%d/1\n%s\n+\n%s\n" % (sample, i, r1, qual))
            f2.write("@%s.%d/2\n%s\n+\n%s\n" % (sample, i, r2, qual))
    return p1, p2


def main():
    os.makedirs(DATA, exist_ok=True)
    genome = {name: random_seq(n) for name, n in CHROMS.items()}
    write_reference(genome)

    samples = [
        # id,            assay,   mark
        ("cuttag_rep1", "CUTTAG", "H3K4me3"),
        ("atac_rep1",   "ATAC",   "NA"),
    ]
    for sid, _assay, _mark in samples:
        write_fastq_pair(sid, genome, n_pairs=4000)

    # standalone-tool sample sheet (TSV)
    with open(os.path.join(DATA, "samples.tsv"), "w") as fh:
        fh.write("SAMPLE_ID\tFASTQ1\tFASTQ2\tASSAY\tMARK\tCONTROL_ID\tLIBTYPE\n")
        for sid, assay, mark in samples:
            fh.write("%s\t%s/%s_R1.fastq.gz\t%s/%s_R2.fastq.gz\t%s\t%s\tNone\tPE\n"
                     % (sid, DATA, sid, DATA, sid, assay, mark))

    # Nextflow sample sheet (CSV)
    with open(os.path.join(DATA, "samplesheet.csv"), "w") as fh:
        fh.write("sample,assay,mark,fastq_1,fastq_2\n")
        for sid, assay, mark in samples:
            fh.write("%s,%s,%s,%s/%s_R1.fastq.gz,%s/%s_R2.fastq.gz\n"
                     % (sid, assay.lower(), mark, DATA, sid, DATA, sid))

    print("Synthetic dataset written to: %s" % DATA)
    print("  reference.fa  (%d contigs)" % len(genome))
    print("  %d samples x paired FASTQ" % len(samples))
    print("  samples.tsv, samplesheet.csv")


if __name__ == "__main__":
    main()
