# ultimaC4walker — build & test automation
#
#   make help        list targets
#   make test        run the dry-run test suite (no bioinformatics tools needed)
#   make docker      build the Docker image
#   make apptainer   build the Apptainer .sif from the local Docker image
#   make example     generate + run the synthetic example
#   make lint        shellcheck the tool (if shellcheck is installed)

VERSION  := 1.0.0
IMAGE    := ultimac4walker
TAG      := $(VERSION)
SHELL    := /bin/bash

.PHONY: help test lint docker apptainer example clean

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) 2>/dev/null \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n",$$1,$$2}' \
	  || sed -n 's/^# *//p' $(MAKEFILE_LIST) | head -8

test: ## Run the dry-run test suite
	bash tests/test_c4walker.sh

lint: ## shellcheck the tool and libraries
	@command -v shellcheck >/dev/null 2>&1 \
	  && shellcheck -x bin/c4walker lib/*.sh tests/*.sh \
	  || echo "shellcheck not installed; skipping"

docker: ## Build the Docker image
	docker build -t $(IMAGE):$(TAG) -t $(IMAGE):latest .

apptainer: ## Build the Apptainer .sif from the local Docker image
	apptainer build c4walker.sif docker-daemon://$(IMAGE):$(TAG)

example: ## Generate + run the bundled synthetic example
	bash example/run_example.sh

clean: ## Remove generated outputs
	rm -rf c4walker_out example/data/*.fastq.gz example/data/*.fa* \
	       example/data/*.bam* example/data/samplesheet.csv \
	       example/results c4walker.sif test_results work .nextflow*
