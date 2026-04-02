---
title: Category Policy and Routing
description: How the pipeline resolves category IDs and uses them to gate module eligibility.
sidebar_position: 3
tags:
  - computational-safety-diligence
---

# Category Policy and Routing

`CATEGORIES.txt` is the current policy source for pipeline category resolution. It defines the supported category IDs, the intent behind each one, and the module-routing rules attached to them.

This matters because the pipeline does not treat category as descriptive metadata. The resolved `category_id` changes which modules are required, which modules are optional, and which modules are explicitly disabled.

## What category controls

Each category policy assigns modules into four buckets:

- `REQUIRED`
- `OPTIONAL`
- `EXPLORATORY`
- `DISABLED`

The resolved category therefore affects:

- what the runner is expected to execute
- what module gaps count as true completeness problems
- what outputs can be interpreted as supported evidence
- what claims should remain out of scope

The resolved `category_id` appears in the module-plan artifacts and should be reviewed with the run manifest before results are interpreted.

## Category resolution model

The current policy is centered on small-molecule workflows. Category resolution depends on what was actually staged for the run, especially:

- whether only ligand information is present
- whether receptor structure is present
- whether trajectory-dependent analysis is in scope
- whether physics-audit eligibility constraints are satisfied
- whether labeled assay data is available

Standard versus Deep is not the same decision as category selection. `config.runMode` controls execution profile and resource depth, while `category_id` controls scientific routing and module eligibility.

## Current supported categories

| Category ID | When to use it | Key routing effect |
| --- | --- | --- |
| `SMALL_MOLECULE__LIGAND_ONLY__NO_STRUCTURE__NO_ASSAYS` | SMILES plus target symbol, but no receptor structure and no labeled assay table | Chemistry, toxicity, precedent, manufacturability, and readiness modules are required; structure-dependent physics modules stay disabled |
| `SMALL_MOLECULE__STRUCTURE_PRESENT__NO_MD_TRAJ` | Receptor structure is available and docking is in scope, but trajectory-dependent analysis is not | Docking becomes required; deeper dynamics and some physics methods remain optional or disabled |
| `SMALL_MOLECULE__STRUCTURE_PRESENT__MD_ENABLED` | Structure is available and dynamics-aware analysis is eligible | Dynamics-aware modules become part of the expected path and several solvent or stability analyses may become optional |
| `SMALL_MOLECULE__STRUCTURE_PRESENT__PHYSICS_AUDIT_ELIGIBLE` | Structure is present and preflight constraints make the physics audit path safe | Physics-heavy modules can be turned on selectively, but they are still not universal defaults |
| `SMALL_MOLECULE__HAS_LABELED_ASSAYS` | Enough labeled activity data exists to support calibration or validation workflows | Assay-aware validation paths such as `y_scramble_validation` become eligible or required, while many structure-heavy methods remain disabled |

## Category-by-category details

### Ligand only, no structure, no assays

**Category ID:** `SMALL_MOLECULE__LIGAND_ONLY__NO_STRUCTURE__NO_ASSAYS`

Use this for fast-fail triage when the package contains ligand information and target identity, but no receptor structure and no labeled assay table.

Required modules include the chemistry, toxicology, precedent, manufacturability, synthesis, uncertainty, and readiness path. Structure-driven modules such as docking, dynamics, and physics binding remain disabled.

### Structure present, no MD trajectory

**Category ID:** `SMALL_MOLECULE__STRUCTURE_PRESENT__NO_MD_TRAJ`

Use this when receptor structure is present and docking is appropriate, but the run is not trajectory-backed.

In this category, `molecular_docking` becomes required. Dynamics, MSM, kinetics, and similar trajectory-dependent analyses remain out of scope unless the package and policy move into a deeper structural category.

### Structure present, MD enabled

**Category ID:** `SMALL_MOLECULE__STRUCTURE_PRESENT__MD_ENABLED`

Use this when the structure-backed workflow is deep enough to support dynamics-aware analysis.

This category keeps the standard chemistry and risk modules, but expands the structural path so modules such as `dynamics_nma` are part of the expected execution set and several solvent, stability, and physics-adjacent modules can become optional.

### Physics audit eligible

**Category ID:** `SMALL_MOLECULE__STRUCTURE_PRESENT__PHYSICS_AUDIT_ELIGIBLE`

Use this only when the staged inputs and preflight checks satisfy the constraints for safe physics-audit execution.

This category is intentionally narrow. Physics-heavy modules are allowed because eligibility has been established, not merely because a structure file exists.

### Labeled assays available

**Category ID:** `SMALL_MOLECULE__HAS_LABELED_ASSAYS`

Use this when the submission includes sufficient labeled activity data to support calibration and validation logic.

This category makes assay-aware validation part of the supported route. In the current policy, `y_scramble_validation` becomes required, while many structure-heavy physics modules remain disabled unless a different structure-backed category is also justified by the staged package.

## Canonical module baseline

The policy file also includes a canonical 40-module baseline snapshot:

- `25` modules listed in the baseline run path
- `14` modules listed as skipped
- `1` module listed as failed

Treat that baseline as a policy snapshot, not as a promise that every environment will execute the same module set on every run. The resolved category, entitlement, staged inputs, and actual runtime conditions still determine the effective module plan.

## Operator and reviewer guidance

When you prepare, validate, or review a run, confirm all of the following:

1. The staged files actually justify the selected or resolved category.
2. The expected required modules for that category appear in the module plan.
3. Any disabled modules are disabled for policy reasons rather than silent input loss.
4. Standard or Deep run profile choices are not being mistaken for scientific category selection.

For category-compatible input packaging, see [Prepare Inputs](./prepare-inputs.md). For the top-level project view, see [Supported Project Types](./supported-project-types.md).
