---
title: Supported Project Types
description: What kinds of projects and input packages can be analyzed.
sidebar_position: 2
tags:
  - computational-safety-diligence
---

# Supported Project Types

Use this page to explain which project categories the core workflow can route today and how those categories affect module eligibility.

For the full category policy, routing rules, and category-specific module gating taken from `CATEGORIES.txt`, see [Category Policy and Routing](./category-policy-and-routing.md).

## Current category policy

The current category policy is centered on small-molecule workflows. Each category determines which module families are:

- Required
- Optional
- Exploratory
- Disabled

This is operationally important because the supported project type is not just a label. It directly affects what the system can evaluate and which downstream outputs are meaningful.

## Category summaries

### Ligand only, no structure, no assays

**Category ID:** `SMALL_MOLECULE__LIGAND_ONLY__NO_STRUCTURE__NO_ASSAYS`

Use this path for fast-fail triage when you only have SMILES plus a target identifier, with no receptor structure and no labeled assay table.

- Required modules emphasize chemistry, toxicity, manufacturability, precedent, and readiness assessment
- Structure-dependent physics modules are disabled
- Exploratory forecasting is permitted but should not be mistaken for baseline support

### Structure present, no MD trajectory

**Category ID:** `SMALL_MOLECULE__STRUCTURE_PRESENT__NO_MD_TRAJ`

Use this path when receptor structure is available and docking-style analyses are possible, but trajectory-dependent dynamics analysis is not yet in scope.

- Docking becomes required
- Dynamics and quantum-heavy methods remain optional or disabled depending on runtime needs

### Structure present, MD enabled

**Category ID:** `SMALL_MOLECULE__STRUCTURE_PRESENT__MD_ENABLED`

Use this path when structure is available and deeper structural-dynamics analyses are eligible from generated or provided trajectories.

- Dynamics-aware modules become part of the expected path
- Additional structure and solvent-sensitive modules can become optional

### Physics audit eligible

**Category ID:** `SMALL_MOLECULE__STRUCTURE_PRESENT__PHYSICS_AUDIT_ELIGIBLE`

Use this path only when ligand preparation and preflight constraints make the physics audit path safe to run.

- Physics audit is optional rather than universal
- Eligibility is gated by preflight-style constraints, not just by the presence of a structure file

### Labeled assays available

**Category ID:** `SMALL_MOLECULE__HAS_LABELED_ASSAYS`

Use this path when sufficient labeled activity data exists to support validation or calibration workflows.

- Assay-aware validation modules become relevant
- Several structure-heavy physics modules can still remain disabled if the assay-led path is the primary framing

## Category selection is evidence-driven

The pipeline does not select category based on operator preference alone. It resolves `category_id` from the actual staged package and the module-planning policy.

In practice, the most important category-driving signals are:

- whether the submission is ligand-only
- whether receptor structure is present
- whether trajectory-backed analysis is intended
- whether the package is physics-audit eligible
- whether labeled assay data is present

Those decisions are separate from `standard` versus `deep` execution mode. Run mode affects depth and infrastructure; category affects scientific routing.

## Canonical module baseline

The current policy also documents a canonical baseline set across the 40-module framing:

- 25 modules in the standard run path
- 14 modules explicitly skipped in the baseline
- 1 module marked failed in the captured policy snapshot

That baseline should be treated as a policy snapshot for documentation and alignment, not as a guarantee that every environment runs the exact same module set under every category.

## Why this page matters

This page helps users answer two questions early:

1. Is my project category actually supported by the current workflow
2. Which module families should I expect to run, remain optional, or stay disabled

For the module-family view, see [Module Index](./modules/module-index.md). For the detailed policy source, see [Category Policy and Routing](./category-policy-and-routing.md).
