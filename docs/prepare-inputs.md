---
title: Prepare Inputs
description: How to assemble input packages for core analysis.
sidebar_position: 5
tags:
  - computational-safety-diligence
---

# Prepare Inputs

This page defines the current input contract for the runner and the core analysis workflow.

## Input root layout

Inputs are discovered from:

```text
<input-root>/<project_id>/01_sources/
```

With the published chart defaults, that usually maps to:

```text
/data/input/<project_id>/01_sources/
```

The required entry point is:

```text
<input-root>/<project_id>/01_sources/sources.json
```

## Minimum required files

At minimum, provide:

1. `sources.json`
2. `portfolio_selected.csv`

The `portfolio_selected.csv` file is resolved through `sources.json`, so both must be present and consistent.

## High-level intake checklist

Before you worry about the runtime folder layout, make sure the submission itself is intelligible. A strong package usually starts with:

- target identifiers such as gene symbols, protein names, aliases, and stable IDs
- compound identifiers or chemical structures such as SMILES
- indication and context-of-use framing
- modality, delivery, or exclusion constraints
- citations or source links when they are available

This is the practical handoff checklist teams use before they normalize the materials into the runner-facing file contract.

## Submission hygiene

The intake material should also follow a few simple packaging rules:

- provide one target per request unless a multi-target workflow has been explicitly approved
- bundle supporting context in a short, structured memo rather than scattering it across unrelated files
- keep filenames stable and self-explanatory
- include known liabilities, historical failure modes, or important exclusions when they are already known
- include specific questions the run should help answer when the submission is exploratory rather than purely operational

## Optional files

Add these when they are available for your project:

- `assays.csv`
- `compounds.csv`
- `targets.csv`
- `structures/*.pdb`

Missing optional files do not necessarily prevent a run, but they can reduce downstream module coverage and interpretation confidence.

## Inputs that change category routing

Some optional-looking files have policy significance because they change category resolution rather than just adding extra context.

Use this rough mapping:

- no structure files and no assay table usually keeps the run in a ligand-only category
- staged receptor structure can move the run into a structure-backed category
- staged labeled assay data can move the run into an assay-aware category
- physics-audit paths require more than a structure file; they also depend on admissibility and preflight constraints

That is why input preparation should be reviewed against [Category Policy and Routing](./category-policy-and-routing.md), not just against the file checklist.

## `sources.json` expectations

`sources.json` should reference files located under the same `01_sources/` directory. Typical keys include:

- `portfolio_selected_csv`
- `primary_candidate_id`
- `assays_csv`
- `compounds_csv`
- `targets_csv`
- `pdbs`

The exact key names can vary slightly by pipeline generation path, but the operational rule is stable: the manifest must point to real files under `01_sources/` that the runner can resolve at runtime.

For customer-facing intake flows, `sources.json` can also carry higher-level context such as:

- `indication`
- `context_of_use`
- `evidence_positive`
- `evidence_negative`

That intake-style context is useful for onboarding and interpretation, but it does not replace the runner-facing file references required at execution time.

## `targets.csv` in onboarding flows

`targets.csv` is optional in the deployed runner contract, but it is commonly used in onboarding and target-diligence intake flows.

Typical columns include:

- `target_symbol`
- `uniprot_id`
- `target_name`
- `hgnc_id`
- `organism`
- `modality`
- `mechanism_of_action`

Use it to make the target context explicit early, then keep the staged runtime bundle aligned with the manifest-driven contract.

## `portfolio_selected.csv` expectations

The selected portfolio file must include one of the following columns:

- `smiles`
- `canonical_smiles`

Recommended additional columns:

- `candidate_id`
- `compound_id`
- `name`
- Any customer metadata columns you want carried forward into downstream context

If you are using multiple candidates, make sure the row identifiers and `primary_candidate_id` in `sources.json` do not conflict.

## Input provenance expectations

Prepare inputs so an operator or auditor can answer these questions without guesswork:

- Which files were supplied by the customer
- Which file is the authoritative selection file
- Which structure files belong to which candidate or target
- Which identifiers should be preserved in exported reports

Keeping that mapping clean improves reproducibility and reduces manual support work later in the run.

## Common failure mode

If the runner fails with an error similar to:

```text
Project directory not found: <input-root>/<project_id>
```

the usual causes are:

- `config.projectId` does not match the staged folder name
- Files were copied into the wrong directory level
- The runner does not have read access to the staged path

Quick check:

```bash
ls -la /data/input/<project_id>/01_sources/
```

## Output scoping note

Input lookup is project-scoped, but outputs are run-scoped:

```text
<output-root>/<run_id>/
```

This is expected behavior and prevents collisions when the same project is run multiple times.

## Recommended validation path

If PreFlight UI is part of your workflow, validate the package before submission:

- [Supported Inputs](../preflight-ui/validation-system/supported-inputs.md)
- [Validation Rules](../preflight-ui/validation-system/validation-rules.md)
- [Troubleshooting](../preflight-ui/validation-system/troubleshooting.md)

Then confirm the staged package is compatible with the intended category path in [Category Policy and Routing](./category-policy-and-routing.md).
