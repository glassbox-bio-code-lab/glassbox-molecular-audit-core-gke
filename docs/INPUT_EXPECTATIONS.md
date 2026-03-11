# Pipeline Input Expectations

This document defines the customer-facing input contract for the CLI/Helm
pipeline runner.

## Note: For more detailed information and troubleshooting, please visit https://docs.glassbox-bio.com.

## Directory layout

Inputs are discovered from:

```
<input-root>/<project_id>/01_sources/
```

With chart defaults, that maps to:

```
/data/input/<project_id>/01_sources/
```

Required path:

```
<input-root>/<project_id>/01_sources/sources.json
```

## Minimum required files

At minimum:

1. `sources.json`
2. `portfolio_selected.csv` (resolved by `sources.json`)

Optional files:

- `assays.csv`
- `compounds.csv`
- `targets.csv`
- `structures/*.pdb`

## `sources.json` expectations

`sources.json` must reference file names/paths under `01_sources/` for the
runner to resolve.

Typical keys include:

- `portfolio_selected_csv` (or equivalent selection pointer)
- `primary_candidate_id` (optional: explicit primary compound used for single-candidate module context)
- `assays_csv` (optional)
- `compounds_csv` (optional)
- `targets_csv` (optional)
- `pdbs` (optional)

If optional keys are missing, the pipeline continues and reports missing module
inputs where applicable.

## `portfolio_selected.csv` expectations

Must include one of:

- `smiles` (preferred)
- `canonical_smiles`

Recommended additional fields:

- `candidate_id` (or `compound_id`/`index`, when using `sources.json.primary_candidate_id`)
- `compound_id`
- `name`
- any customer metadata columns you want echoed in downstream analysis context

## Common failure mode

If the runner fails with:

```
Project directory not found: <input-root>/<project_id>
```

then either:

- `config.projectId` does not match the staged folder name, or
- files were copied into the wrong path level.

Quick check:

```bash
ls -la /data/input/<project_id>/01_sources/
```

## Run-id output note

Input lookup is **project-id scoped**, but outputs are **run-id scoped** under:

```
<output-root>/<run_id>/
```

This is expected and prevents output collisions across runs for the same
project.
