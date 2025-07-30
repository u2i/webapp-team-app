# Kubernetes Manifest Consolidation Plan

## Current Issues

1. **Multiple PDB definitions** with conflicting values:
   - Base: minAvailable=2
   - Overlays (dev/qa/preview): minAvailable=1
   - Profile dev: minAvailable=0
   - Profile prod: minAvailable=2

2. **Duplicate namespace files**:
   - namespace.yaml (template)
   - namespace-nonprod.yaml
   - namespace-prod.yaml
   - overlays/preview/namespace.yaml

3. **Certificate template issues**:
   - Base template has PLACEHOLDER values
   - Preview has separate certificate-resources.yaml

4. **Confusion between overlays and profiles**:
   - Both modify the same resources
   - Unclear which takes precedence
   - Different values for same parameters

## Proposed Structure

```
k8s-clean/
├── base/                      # Core resources
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── network-policy.yaml
│   ├── gateway-route.yaml
│   ├── pod-disruption-budget.yaml
│   └── certificate.yaml       # Parameterized template
│
├── components/                # Reusable modifications
│   ├── pdb-minAvailable-0/   # For dev (allow all disruptions)
│   ├── pdb-minAvailable-1/   # For qa/preview (keep 1 pod)
│   └── hpa/                  # Horizontal pod autoscaler
│
├── overlays/                 # Environment-specific configs
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── # References components/pdb-minAvailable-0
│   ├── qa/
│   │   ├── kustomization.yaml
│   │   └── # References components/pdb-minAvailable-1
│   ├── preview/
│   │   ├── kustomization.yaml
│   │   └── # References components/pdb-minAvailable-1
│   └── production/
│       ├── kustomization.yaml
│       └── # Uses base PDB (minAvailable=2)
│
├── namespace/                # Single unified namespace template
│   └── namespace.yaml        # Accepts PROJECT_ID parameter
│
└── kcc/                     # Config Connector resources
    └── base/
        └── certificate.yaml  # Parameterized certificate template
```

## Benefits

1. **Clear separation of concerns**:
   - Base: Common configuration
   - Components: Reusable patches
   - Overlays: Environment-specific assembly

2. **Reduced duplication**:
   - Single PDB component for non-prod
   - One namespace template
   - One certificate template

3. **Easier maintenance**:
   - Change PDB value in one place
   - Consistent parameter handling
   - Clear inheritance model

## Implementation Steps

1. **Phase 1: Consolidate PDB patches**
   - Create components/pdb-minAvailable-1
   - Update overlays to use component
   - Remove duplicate pdb-patch.yaml files

2. **Phase 2: Unify namespace templates**
   - Create single parameterized namespace.yaml
   - Update references in Skaffold configs
   - Remove duplicate namespace files

3. **Phase 3: Clarify profiles vs overlays**
   - Document when to use each
   - Consider merging into single approach
   - Remove conflicting configurations

4. **Phase 4: Parameterize hardcoded values**
   - Extract common values to ConfigMaps
   - Use Kustomize variables for repeated values
   - Document all parameters

## Migration Impact

- No changes to deployment process
- Skaffold configs may need path updates
- Cloud Deploy parameters remain the same
- Reduced maintenance burden going forward