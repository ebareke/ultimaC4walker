# shellcheck shell=bash
# ---------------------------------------------------------------------------
# lib/hpc.sh — HPC job-script generation (SLURM + PBS)
#
# In `slurm` / `pbs` run modes the driver does not process samples itself;
# it emits one job script per sample that re-invokes c4walker with
# --run-single, then submits it with sbatch / qsub.
# ---------------------------------------------------------------------------

# c4_submit_slurm SAMPLE_ID
c4_submit_slurm() {
  local sample_id="$1"
  local jobdir="$OUTDIR/jobs/slurm"; mkdir -p "$jobdir"
  local jobfile="$jobdir/${sample_id}.slurm.sh"

  cat > "$jobfile" <<EOF
#!/usr/bin/env bash
#SBATCH --job-name=$(cfg PROJECT_NAME c4walker)_${sample_id}
#SBATCH --partition=$(cfg SLURM_PARTITION general)
#SBATCH --cpus-per-task=$(cfg THREADS 4)
#SBATCH --time=$(cfg SLURM_TIME 24:00:00)
#SBATCH --mem=$(cfg SLURM_MEM 32G)
#SBATCH --output=$OUTDIR/logs/${sample_id}.slurm.out
#SBATCH --error=$OUTDIR/logs/${sample_id}.slurm.err

set -euo pipefail
"$C4_SELF" -c "$CONFIG_YAML" -s "$SAMPLES" --run-single "${sample_id}"
EOF

  if [ "${DRYRUN:-0}" -eq 1 ]; then
    log_info "[DRY] sbatch $jobfile"
  else
    run_cmd "sbatch '$jobfile'"
  fi
}

# c4_submit_pbs SAMPLE_ID
c4_submit_pbs() {
  local sample_id="$1"
  local jobdir="$OUTDIR/jobs/pbs"; mkdir -p "$jobdir"
  local jobfile="$jobdir/${sample_id}.pbs.sh"

  cat > "$jobfile" <<EOF
#!/usr/bin/env bash
#PBS -N $(cfg PROJECT_NAME c4walker)_${sample_id}
#PBS -q $(cfg PBS_QUEUE batch)
#PBS -l walltime=$(cfg PBS_TIME 24:00:00)
#PBS -l mem=$(cfg PBS_MEM 32gb)
#PBS -l nodes=1:ppn=$(cfg THREADS 4)
#PBS -o $OUTDIR/logs/${sample_id}.pbs.out
#PBS -e $OUTDIR/logs/${sample_id}.pbs.err

cd \$PBS_O_WORKDIR
set -euo pipefail
"$C4_SELF" -c "$CONFIG_YAML" -s "$SAMPLES" --run-single "${sample_id}"
EOF

  if [ "${DRYRUN:-0}" -eq 1 ]; then
    log_info "[DRY] qsub $jobfile"
  else
    run_cmd "qsub '$jobfile'"
  fi
}
