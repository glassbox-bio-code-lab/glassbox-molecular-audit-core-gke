SHELL := /bin/bash

APP_NAME ?= glassbox-mol-audit
NAMESPACE ?= glassbox-mol-audit
CHART_DIR ?= ./manifest/chart

STANDARD_IMAGE_REPO ?= us-docker.pkg.dev/glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit
DEEP_IMAGE_REPO ?= us-docker.pkg.dev/glassbox-bio-public/glassbox-bio-molecular-audit/glassbox-mol-audit/deep-tools

STANDARD_IMAGE_TAG ?= 1.0.0
DEEP_IMAGE_TAG ?= 1.0.0
STANDARD_IMAGE_DIGEST ?= sha256:c48760f3e5f089fe0c35f2f11c6d6c876b8cc210632913bef82b98537faae065
DEEP_IMAGE_DIGEST ?= sha256:7754aa922cffe73963027d20d9b71aa0edcc015f1ae8445ec021b6032b84db28
HELPER_IMAGE_REPO ?= alpine
HELPER_IMAGE_TAG ?= 3.20
HELPER_IMAGE_DIGEST ?=

PROJECT_ID ?=
RUN_MODE ?= standard
CATEGORY_ID ?=
RUN_ID ?=

ENTITLEMENT_URL ?= https://glassbox-seal-662656813262.us-central1.run.app
ENTITLEMENT_AUTH_MODE ?= google
ENTITLEMENT_AUDIENCE ?= $(ENTITLEMENT_URL)
WORKLOAD_IDENTITY_GSA ?=  

PVC_NAME ?= glassbox-mol-audit-data
PVC_LOADER_POD ?= pvc-loader
INPUT_ROOT ?= ./e2e/sample_input
OUTPUT_DIR ?= ./e2e/downloads
RUN_ID_FILE ?= ./.last_manifest_run_id
RUN_ID_FILE_STANDARD ?= ./.last_manifest_run_id.standard
RUN_ID_FILE_DEEP ?= ./.last_manifest_run_id.deep

.PHONY: help \
		review-preflight \
		reviewer-run-standard reviewer-run-deep \
		deploy-manifest-infra stage-manifest-input deploy-manifest-job fetch-manifest-output \
		deploy-manifest-infra-standard stage-manifest-input-standard deploy-manifest-job-standard fetch-manifest-output-standard \
		deploy-manifest-infra-deep stage-manifest-input-deep deploy-manifest-job-deep fetch-manifest-output-deep

help:
	@echo "Reviewer workflow (generic):"
	@echo "  make deploy-manifest-infra RUN_MODE=<standard|deep> [STANDARD_IMAGE_TAG=<tag>|STANDARD_IMAGE_DIGEST=<sha>] [DEEP_IMAGE_TAG=<tag>|DEEP_IMAGE_DIGEST=<sha>]"
	@echo "  make stage-manifest-input PROJECT_ID=<id> RUN_MODE=<standard|deep>"
	@echo "  make deploy-manifest-job PROJECT_ID=<id> RUN_MODE=<standard|deep> CATEGORY_ID=<category> WORKLOAD_IDENTITY_GSA=<gsa>"
	@echo "  make fetch-manifest-output RUN_MODE=<standard|deep>"
	@echo ""
	@echo "Reviewer workflow (standard):"
	@echo "  make reviewer-run-standard PROJECT_ID=<id> CATEGORY_ID=<category> STANDARD_IMAGE_DIGEST=<sha256:...> WORKLOAD_IDENTITY_GSA=<gsa>"
	@echo "    # runs infra, stages input, waits for job completion, then downloads outputs"
	@echo ""
	@echo "  make deploy-manifest-infra-standard STANDARD_IMAGE_TAG=<tag>|STANDARD_IMAGE_DIGEST=<sha256:...>"
	@echo "  make stage-manifest-input-standard PROJECT_ID=<id>"
	@echo "  make deploy-manifest-job-standard PROJECT_ID=<id> CATEGORY_ID=<category> WORKLOAD_IDENTITY_GSA=<gsa>"
	@echo "  make fetch-manifest-output-standard"
	@echo ""
	@echo "Reviewer workflow (deep):"
	@echo "  make reviewer-run-deep PROJECT_ID=<id> CATEGORY_ID=<category> DEEP_IMAGE_DIGEST=<sha256:...> WORKLOAD_IDENTITY_GSA=<gsa>"
	@echo "    # runs infra, stages input, waits for job completion, then downloads outputs"
	@echo ""
	@echo "  make deploy-manifest-infra-deep DEEP_IMAGE_TAG=<tag>|DEEP_IMAGE_DIGEST=<sha256:...>"
	@echo "  make stage-manifest-input-deep PROJECT_ID=<id>"
	@echo "  make deploy-manifest-job-deep PROJECT_ID=<id> CATEGORY_ID=<category> WORKLOAD_IDENTITY_GSA=<gsa>"
	@echo "  make fetch-manifest-output-deep"
	@echo ""
	@echo "Preflight:"
	@echo "  make review-preflight"
	@echo ""
	@echo "Optional:"
	@echo "  RUN_ID=<custom-run-id>      # otherwise reviewer_<mode>_<timestamp> is used"

review-preflight:
	@echo "[preflight] Helm lint"
	@helm lint "$(CHART_DIR)"
	@echo "[preflight] Helm template (default)"
	@helm template review-default "$(CHART_DIR)" >/dev/null
	@echo "[preflight] Helm template (standard profile)"
	@helm template review-standard "$(CHART_DIR)" -f "$(CHART_DIR)/values-standard.yaml" >/dev/null
	@echo "[preflight] Helm template (deep profile)"
	@helm template review-deep "$(CHART_DIR)" -f "$(CHART_DIR)/values-standard.yaml" -f "$(CHART_DIR)/values-gpu.yaml" >/dev/null
	@echo "[preflight] Helm template (job enabled + required category)"
	@helm template review-job "$(CHART_DIR)" -f "$(CHART_DIR)/values-standard.yaml" --set job.enabled=true --set config.categoryId=SMALL_MOLECULE__STRUCTURE_PRESENT__NO_MD_TRAJ >/dev/null
	@echo "[preflight] Shell syntax"
	@find . -type f -name '*.sh' -print0 | xargs -0 -r bash -n
	@echo "[preflight] CRLF guard for shell scripts"
	@if rg -n "$$(printf '\r')" --glob '*.sh' . >/tmp/gbx_crlf_hits.txt; then \
		echo "ERROR: CRLF line endings detected in shell scripts:"; \
		cat /tmp/gbx_crlf_hits.txt; \
		exit 1; \
	fi
	@echo "[preflight] Required customer docs"
	@test -f ./docs/RUNBOOK_CUSTOMER.md
	@test -f ./docs/SUPPORT_MATRIX.md
	@echo "[preflight] Required internal release docs"
	@test -f ../docs/MARKETPLACE_REVIEW_CHECKLIST.md
	@echo "[preflight] Required sample input bundle"
	@test -f ./e2e/sample_input/test/01_sources/sources.json
	@test -f ./e2e/sample_input/test/01_sources/portfolio_selected.csv
	@echo "[preflight] PASS"

deploy-manifest-infra:
	@IMAGE_REPO_RESOLVED="$(STANDARD_IMAGE_REPO)"; \
	IMAGE_TAG_RESOLVED="$(STANDARD_IMAGE_TAG)"; \
	IMAGE_DIGEST_RESOLVED="$(STANDARD_IMAGE_DIGEST)"; \
	if [ "$(RUN_MODE)" = "deep" ]; then \
		IMAGE_REPO_RESOLVED="$(DEEP_IMAGE_REPO)"; \
		IMAGE_TAG_RESOLVED="$(DEEP_IMAGE_TAG)"; \
		IMAGE_DIGEST_RESOLVED="$(DEEP_IMAGE_DIGEST)"; \
	fi; \
	if [ -z "$$IMAGE_DIGEST_RESOLVED" ] && [ -z "$$IMAGE_TAG_RESOLVED" ]; then echo "ERROR: resolved image tag/digest is empty for RUN_MODE=$(RUN_MODE)"; exit 2; fi; \
	VALUES_ARGS="-f $(CHART_DIR)/values-standard.yaml"; \
	if [ "$(RUN_MODE)" = "deep" ]; then VALUES_ARGS="$$VALUES_ARGS -f $(CHART_DIR)/values-gpu.yaml"; fi; \
	STORAGE_ARGS=""; \
	if kubectl -n "$(NAMESPACE)" get pvc "$(PVC_NAME)" >/dev/null 2>&1; then \
		PVC_SC="$$(kubectl -n "$(NAMESPACE)" get pvc "$(PVC_NAME)" -o jsonpath='{.spec.storageClassName}')"; \
		PVC_SIZE="$$(kubectl -n "$(NAMESPACE)" get pvc "$(PVC_NAME)" -o jsonpath='{.status.capacity.storage}')"; \
		STORAGE_ARGS="--set-string storage.pvc.storageClassName=$$PVC_SC --set-string storage.pvc.size=$$PVC_SIZE"; \
	fi; \
	IMAGE_ARGS="--set image.repository=$$IMAGE_REPO_RESOLVED"; \
	if [ -n "$$IMAGE_DIGEST_RESOLVED" ]; then IMAGE_ARGS="$$IMAGE_ARGS --set image.digest=$$IMAGE_DIGEST_RESOLVED"; else IMAGE_ARGS="$$IMAGE_ARGS --set image.tag=$$IMAGE_TAG_RESOLVED"; fi; \
	WI_ARGS=""; \
	if [ -n "$(WORKLOAD_IDENTITY_GSA)" ]; then WI_ARGS="--set workloadIdentity.enabled=true --set-string workloadIdentity.gcpServiceAccount=$(WORKLOAD_IDENTITY_GSA)"; fi; \
	echo "Using IMAGE_REPO=$$IMAGE_REPO_RESOLVED"; \
	if [ -n "$$IMAGE_DIGEST_RESOLVED" ]; then echo "Using IMAGE_DIGEST=$$IMAGE_DIGEST_RESOLVED"; else echo "Using IMAGE_TAG=$$IMAGE_TAG_RESOLVED"; fi; \
	eval helm upgrade --install "$(APP_NAME)" "$(CHART_DIR)" \
		--namespace "$(NAMESPACE)" \
		--create-namespace \
		$$VALUES_ARGS \
		--set job.enabled=false \
		$$STORAGE_ARGS \
		$$IMAGE_ARGS \
		--set-string config.entitlementUrl="$(ENTITLEMENT_URL)" \
		--set-string config.entitlementAuthMode="$(ENTITLEMENT_AUTH_MODE)" \
		--set-string config.entitlementAudience="$(ENTITLEMENT_AUDIENCE)" \
		$$WI_ARGS; \
	kubectl -n "$(NAMESPACE)" get pvc "$(PVC_NAME)" >/dev/null 2>&1 || { echo "ERROR: PVC $(PVC_NAME) was not created"; exit 1; }; \
	kubectl -n "$(NAMESPACE)" get pvc "$(PVC_NAME)"

stage-manifest-input:
	@if [ -z "$(PROJECT_ID)" ]; then echo "ERROR: PROJECT_ID is required"; exit 2; fi
	@if [ ! -d "$(INPUT_ROOT)/$(PROJECT_ID)" ]; then echo "ERROR: local input dir not found: $(INPUT_ROOT)/$(PROJECT_ID)"; exit 2; fi
	@HELPER_REPO="$(HELPER_IMAGE_REPO)"; \
	HELPER_TAG="$(HELPER_IMAGE_TAG)"; \
	HELPER_DIGEST="$(HELPER_IMAGE_DIGEST)"; \
	if [ -z "$$HELPER_DIGEST" ] && [ -z "$$HELPER_TAG" ]; then echo "ERROR: resolved helper image tag/digest is empty for RUN_MODE=$(RUN_MODE)"; exit 2; fi; \
	if [ -n "$$HELPER_DIGEST" ]; then HELPER_IMAGE="$$HELPER_REPO@$$HELPER_DIGEST"; else HELPER_IMAGE="$$HELPER_REPO:$$HELPER_TAG"; fi; \
	echo "Using helper image=$$HELPER_IMAGE"; \
	kubectl -n "$(NAMESPACE)" delete pod "$(PVC_LOADER_POD)" --ignore-not-found >/dev/null 2>&1 || true; \
	kubectl -n "$(NAMESPACE)" delete pod "$(PVC_LOADER_POD)" --grace-period=0 --force --ignore-not-found >/dev/null 2>&1 || true; \
	kubectl -n "$(NAMESPACE)" wait --for=delete pod/"$(PVC_LOADER_POD)" --timeout=30s >/dev/null 2>&1 || true; \
		printf '%s\n' \
		  'apiVersion: v1' \
		  'kind: Pod' \
		  'metadata:' \
		  '  name: $(PVC_LOADER_POD)' \
		  'spec:' \
		  '  restartPolicy: Never' \
		  '  containers:' \
		  '    - name: $(PVC_LOADER_POD)' \
		  "      image: $$HELPER_IMAGE" \
		  '      imagePullPolicy: IfNotPresent' \
		  '      command: ["sh","-lc"]' \
		  '      args: ["sleep 3600"]' \
		  '      volumeMounts:' \
		  '        - name: data' \
		  '          mountPath: /data' \
		  '  volumes:' \
		  '    - name: data' \
		  '      persistentVolumeClaim:' \
		  '        claimName: "$(PVC_NAME)"' | kubectl -n "$(NAMESPACE)" apply -f - >/dev/null; \
	kubectl -n "$(NAMESPACE)" wait --for=condition=Ready pod/"$(PVC_LOADER_POD)" --timeout=120s; \
	kubectl -n "$(NAMESPACE)" exec "$(PVC_LOADER_POD)" -- sh -lc 'mkdir -p /data/input'; \
	kubectl -n "$(NAMESPACE)" cp "$(INPUT_ROOT)/$(PROJECT_ID)" "$(NAMESPACE)/$(PVC_LOADER_POD):/data/input/$(PROJECT_ID)"; \
	kubectl -n "$(NAMESPACE)" exec "$(PVC_LOADER_POD)" -- sh -lc 'chmod -R a+rwX /data/input/$(PROJECT_ID) >/dev/null 2>&1 || echo "WARN: chmod not permitted on mounted input path; continuing"; find /data/input/$(PROJECT_ID) -maxdepth 2 -type f | head'

deploy-manifest-job:
	@if [ -z "$(PROJECT_ID)" ]; then echo "ERROR: PROJECT_ID is required"; exit 2; fi
	@if [ -z "$(CATEGORY_ID)" ]; then echo "ERROR: CATEGORY_ID is required"; exit 2; fi
	@if [ -z "$(WORKLOAD_IDENTITY_GSA)" ]; then echo "ERROR: WORKLOAD_IDENTITY_GSA is required"; exit 2; fi
	@RUN_ID="$${RUN_ID:-reviewer_$(RUN_MODE)_$$(date -u +%Y%m%dT%H%M%SZ)}"; \
	IMAGE_REPO_RESOLVED="$(STANDARD_IMAGE_REPO)"; \
	IMAGE_TAG_RESOLVED="$(STANDARD_IMAGE_TAG)"; \
	IMAGE_DIGEST_RESOLVED="$(STANDARD_IMAGE_DIGEST)"; \
	if [ "$(RUN_MODE)" = "deep" ]; then \
		IMAGE_REPO_RESOLVED="$(DEEP_IMAGE_REPO)"; \
		IMAGE_TAG_RESOLVED="$(DEEP_IMAGE_TAG)"; \
		IMAGE_DIGEST_RESOLVED="$(DEEP_IMAGE_DIGEST)"; \
	fi; \
	if [ -z "$$IMAGE_DIGEST_RESOLVED" ] && [ -z "$$IMAGE_TAG_RESOLVED" ]; then echo "ERROR: resolved image tag/digest is empty for RUN_MODE=$(RUN_MODE)"; exit 2; fi; \
	printf '%s\n' "$$RUN_ID" > "$(RUN_ID_FILE)"; \
	echo "Using RUN_ID=$$RUN_ID"; \
	echo "Using IMAGE_REPO=$$IMAGE_REPO_RESOLVED"; \
	if [ -n "$$IMAGE_DIGEST_RESOLVED" ]; then echo "Using IMAGE_DIGEST=$$IMAGE_DIGEST_RESOLVED"; else echo "Using IMAGE_TAG=$$IMAGE_TAG_RESOLVED"; fi; \
	VALUES_ARGS="-f $(CHART_DIR)/values-standard.yaml"; \
	if [ "$(RUN_MODE)" = "deep" ]; then VALUES_ARGS="$$VALUES_ARGS -f $(CHART_DIR)/values-gpu.yaml"; fi; \
	STORAGE_ARGS=""; \
	if kubectl -n "$(NAMESPACE)" get pvc "$(PVC_NAME)" >/dev/null 2>&1; then \
		PVC_SC="$$(kubectl -n "$(NAMESPACE)" get pvc "$(PVC_NAME)" -o jsonpath='{.spec.storageClassName}')"; \
		PVC_SIZE="$$(kubectl -n "$(NAMESPACE)" get pvc "$(PVC_NAME)" -o jsonpath='{.status.capacity.storage}')"; \
		STORAGE_ARGS="--set-string storage.pvc.storageClassName=$$PVC_SC --set-string storage.pvc.size=$$PVC_SIZE"; \
	fi; \
	IMAGE_ARGS="--set image.repository=$$IMAGE_REPO_RESOLVED"; \
	if [ -n "$$IMAGE_DIGEST_RESOLVED" ]; then IMAGE_ARGS="$$IMAGE_ARGS --set image.digest=$$IMAGE_DIGEST_RESOLVED"; else IMAGE_ARGS="$$IMAGE_ARGS --set image.tag=$$IMAGE_TAG_RESOLVED"; fi; \
	kubectl -n "$(NAMESPACE)" delete pod "$(PVC_LOADER_POD)" --ignore-not-found; \
	kubectl -n "$(NAMESPACE)" delete job "$(APP_NAME)" --ignore-not-found; \
	eval helm upgrade --install "$(APP_NAME)" "$(CHART_DIR)" \
		--namespace "$(NAMESPACE)" \
		--create-namespace \
		$$VALUES_ARGS \
		--set job.enabled=true \
		$$STORAGE_ARGS \
		$$IMAGE_ARGS \
		--set-string config.projectId="$(PROJECT_ID)" \
		--set-string config.runMode="$(RUN_MODE)" \
		--set-string config.runId="$$RUN_ID" \
		--set-string config.categoryId="$(CATEGORY_ID)" \
		--set-string config.entitlementUrl="$(ENTITLEMENT_URL)" \
		--set-string config.entitlementAuthMode="$(ENTITLEMENT_AUTH_MODE)" \
		--set-string config.entitlementAudience="$(ENTITLEMENT_AUDIENCE)" \
		--set workloadIdentity.enabled=true \
		--set-string workloadIdentity.gcpServiceAccount="$(WORKLOAD_IDENTITY_GSA)"; \
	kubectl -n "$(NAMESPACE)" get pods; \
	kubectl -n "$(NAMESPACE)" wait --for=condition=complete job/"$(APP_NAME)" --timeout=7200s || { \
		kubectl -n "$(NAMESPACE)" get pods; \
		kubectl -n "$(NAMESPACE)" describe job "$(APP_NAME)"; \
		exit 1; \
	}; \
	kubectl -n "$(NAMESPACE)" get pods

fetch-manifest-output:
	@RUN_ID="$${RUN_ID:-$$(cat "$(RUN_ID_FILE)" 2>/dev/null)}"; \
	if [ -z "$$RUN_ID" ]; then echo "ERROR: RUN_ID is required or $(RUN_ID_FILE) must exist"; exit 2; fi; \
	HELPER_REPO="$(HELPER_IMAGE_REPO)"; \
	HELPER_TAG="$(HELPER_IMAGE_TAG)"; \
	HELPER_DIGEST="$(HELPER_IMAGE_DIGEST)"; \
	if [ -z "$$HELPER_DIGEST" ] && [ -z "$$HELPER_TAG" ]; then echo "ERROR: resolved helper image tag/digest is empty for RUN_MODE=$(RUN_MODE)"; exit 2; fi; \
	if [ -n "$$HELPER_DIGEST" ]; then HELPER_IMAGE="$$HELPER_REPO@$$HELPER_DIGEST"; else HELPER_IMAGE="$$HELPER_REPO:$$HELPER_TAG"; fi; \
	echo "Fetching RUN_ID=$$RUN_ID"; \
	kubectl -n "$(NAMESPACE)" delete job "$(APP_NAME)" --ignore-not-found; \
	kubectl -n "$(NAMESPACE)" delete pod "$(PVC_LOADER_POD)" --ignore-not-found >/dev/null 2>&1 || true; \
	kubectl -n "$(NAMESPACE)" delete pod "$(PVC_LOADER_POD)" --grace-period=0 --force --ignore-not-found >/dev/null 2>&1 || true; \
	kubectl -n "$(NAMESPACE)" wait --for=delete pod/"$(PVC_LOADER_POD)" --timeout=30s >/dev/null 2>&1 || true; \
		printf '%s\n' \
		  'apiVersion: v1' \
		  'kind: Pod' \
		  'metadata:' \
		  '  name: $(PVC_LOADER_POD)' \
		  'spec:' \
		  '  restartPolicy: Never' \
		  '  containers:' \
		  '    - name: $(PVC_LOADER_POD)' \
		  "      image: $$HELPER_IMAGE" \
		  '      imagePullPolicy: IfNotPresent' \
		  '      command: ["sh","-lc"]' \
		  '      args: ["sleep 3600"]' \
		  '      volumeMounts:' \
		  '        - name: data' \
		  '          mountPath: /data' \
		  '  volumes:' \
		  '    - name: data' \
		  '      persistentVolumeClaim:' \
		  '        claimName: "$(PVC_NAME)"' | kubectl -n "$(NAMESPACE)" apply -f - >/dev/null; \
	kubectl -n "$(NAMESPACE)" wait --for=condition=Ready pod/"$(PVC_LOADER_POD)" --timeout=120s; \
	mkdir -p "$(OUTPUT_DIR)"; \
	kubectl -n "$(NAMESPACE)" cp "$(NAMESPACE)/$(PVC_LOADER_POD):/data/output/$$RUN_ID" "$(OUTPUT_DIR)/$$RUN_ID"; \
	kubectl -n "$(NAMESPACE)" delete pod "$(PVC_LOADER_POD)"

deploy-manifest-infra-standard:
	@$(MAKE) deploy-manifest-infra RUN_MODE=standard

stage-manifest-input-standard:
	@$(MAKE) stage-manifest-input RUN_MODE=standard

deploy-manifest-job-standard:
	@$(MAKE) deploy-manifest-job RUN_MODE=standard RUN_ID_FILE="$(RUN_ID_FILE_STANDARD)"

fetch-manifest-output-standard:
	@$(MAKE) fetch-manifest-output RUN_MODE=standard RUN_ID_FILE="$(RUN_ID_FILE_STANDARD)"

deploy-manifest-infra-deep:
	@$(MAKE) deploy-manifest-infra RUN_MODE=deep

stage-manifest-input-deep:
	@$(MAKE) stage-manifest-input RUN_MODE=deep

deploy-manifest-job-deep:
	@$(MAKE) deploy-manifest-job RUN_MODE=deep RUN_ID_FILE="$(RUN_ID_FILE_DEEP)"

fetch-manifest-output-deep:
	@$(MAKE) fetch-manifest-output RUN_MODE=deep RUN_ID_FILE="$(RUN_ID_FILE_DEEP)"

reviewer-run-standard:
	@$(MAKE) deploy-manifest-infra-standard WORKLOAD_IDENTITY_GSA="$(WORKLOAD_IDENTITY_GSA)"
	@$(MAKE) stage-manifest-input-standard PROJECT_ID="$(PROJECT_ID)"
	@$(MAKE) deploy-manifest-job-standard PROJECT_ID="$(PROJECT_ID)" CATEGORY_ID="$(CATEGORY_ID)" WORKLOAD_IDENTITY_GSA="$(WORKLOAD_IDENTITY_GSA)"
	@$(MAKE) fetch-manifest-output-standard

reviewer-run-deep:
	@$(MAKE) deploy-manifest-infra-deep WORKLOAD_IDENTITY_GSA="$(WORKLOAD_IDENTITY_GSA)"
	@$(MAKE) stage-manifest-input-deep PROJECT_ID="$(PROJECT_ID)"
	@$(MAKE) deploy-manifest-job-deep PROJECT_ID="$(PROJECT_ID)" CATEGORY_ID="$(CATEGORY_ID)" WORKLOAD_IDENTITY_GSA="$(WORKLOAD_IDENTITY_GSA)"
	@$(MAKE) fetch-manifest-output-deep
