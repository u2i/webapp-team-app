# Config Connector Configuration
# This file manages the Config Connector installation and configuration

# Install Config Connector Operator
resource "kubectl_manifest" "config_connector_operator" {
  for_each = {
    "01-namespace" = <<-YAML
      apiVersion: v1
      kind: Namespace
      metadata:
        name: configconnector-operator-system
    YAML
    
    "02-configconnector-crd" = <<-YAML
      apiVersion: apiextensions.k8s.io/v1
      kind: CustomResourceDefinition
      metadata:
        name: configconnectorcontexts.core.cnrm.cloud.google.com
      spec:
        group: core.cnrm.cloud.google.com
        names:
          kind: ConfigConnectorContext
          listKind: ConfigConnectorContextList
          plural: configconnectorcontexts
          singular: configconnectorcontext
        scope: Namespaced
        versions:
        - name: v1beta1
          schema:
            openAPIV3Schema:
              type: object
              properties:
                spec:
                  type: object
                  properties:
                    googleServiceAccount:
                      type: string
                    requestProjectPolicy:
                      type: string
                      enum: ["USER_SPECIFIED", "RESOURCE_PROJECT", "BILLING_PROJECT"]
                    billingProject:
                      type: string
                status:
                  type: object
                  properties:
                    healthy:
                      type: boolean
                    errors:
                      type: array
                      items:
                        type: string
          served: true
          storage: true
          subresources:
            status: {}
    YAML
  }

  yaml_body = each.value
}

# Download and apply Config Connector operator for Autopilot
resource "null_resource" "install_config_connector_operator" {
  depends_on = [
    google_container_cluster.webapp_cluster,
    kubectl_manifest.config_connector_operator
  ]

  # Force re-run if cluster changes
  triggers = {
    cluster_id = google_container_cluster.webapp_cluster.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Get cluster credentials
      gcloud container clusters get-credentials ${var.gke_cluster_name} \
        --region ${var.primary_region} \
        --project ${data.google_project.tenant_app.project_id}
      
      # Create a temporary directory for the installation
      TEMP_DIR=$(mktemp -d)
      cd $TEMP_DIR
      
      # Download the Config Connector operator bundle
      echo "Downloading Config Connector operator..."
      gcloud storage cp gs://configconnector-operator/latest/release-bundle.tar.gz release-bundle.tar.gz
      
      # Extract the bundle
      tar zxvf release-bundle.tar.gz
      
      # Apply the Autopilot-specific operator manifest
      kubectl apply -f operator-system/autopilot-configconnector-operator.yaml
      
      # Wait for the operator to be ready
      echo "Waiting for Config Connector operator to be ready..."
      kubectl wait --for=condition=Ready pod -n configconnector-operator-system --all --timeout=300s
      
      # Clean up
      cd -
      rm -rf $TEMP_DIR
      
      echo "Config Connector operator installed successfully"
    EOT
  }
}

# Wait for operator to create ConfigConnector CRD
resource "null_resource" "wait_for_operator_crds" {
  depends_on = [null_resource.install_config_connector_operator]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Config Connector operator to create CRDs..."
      timeout 300 bash -c 'until kubectl get crd configconnectors.core.cnrm.cloud.google.com 2>/dev/null; do sleep 5; done'
      echo "ConfigConnector CRD is ready!"
    EOT
  }
}

# Create ConfigConnector object
resource "kubectl_manifest" "config_connector" {
  depends_on = [null_resource.wait_for_operator_crds]

  yaml_body = <<-YAML
apiVersion: core.cnrm.cloud.google.com/v1beta1
kind: ConfigConnector
metadata:
  # the name is restricted to ensure that there is only one
  # ConfigConnector resource installed in your cluster
  name: configconnector.core.cnrm.cloud.google.com
spec:
  mode: cluster
  googleServiceAccount: ${google_service_account.config_connector.email}
  # Setting stateIntoSpec to Absent is recommended. It prevents Config Connector 
  # from populating unspecified fields into the spec.
  stateIntoSpec: Absent
  YAML
}

# Config Connector namespace for webapp resources
resource "kubectl_manifest" "webapp_namespace" {
  depends_on = [kubectl_manifest.config_connector]

  yaml_body = <<-YAML
apiVersion: v1
kind: Namespace
metadata:
  name: webapp-resources
  annotations:
    cnrm.cloud.google.com/project-id: ${data.google_project.tenant_app.project_id}
  labels:
    managed-by: config-connector
    compliance: iso27001-soc2-gdpr
    data-residency: eu
    gdpr-compliant: "true"
YAML
}

# Note: cnrm-system namespace is created automatically by the operator
# We don't need to create it manually for namespaced mode

# Wait for Config Connector to be ready
resource "null_resource" "wait_for_config_connector" {
  depends_on = [
    kubectl_manifest.config_connector,
    kubectl_manifest.webapp_namespace
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Config Connector to be ready..."
      
      # For cluster mode, wait for the controller to be ready in cnrm-system namespace
      echo "Checking Config Connector status..."
      sleep 30
      kubectl get configconnector configconnector.core.cnrm.cloud.google.com -o yaml
      
      # Wait for Config Connector pods in cnrm-system namespace
      kubectl wait --for=condition=Ready pods -n cnrm-system -l cnrm.cloud.google.com/component=cnrm-controller-manager --timeout=600s || {
        echo "Config Connector pods not ready after 10 minutes. Checking all namespaces..."
        kubectl get pods --all-namespaces | grep cnrm
        kubectl describe configconnector configconnector.core.cnrm.cloud.google.com
      }
      
      # Wait for CRDs to be available
      echo "Waiting for Config Connector CRDs..."
      timeout 300 bash -c 'until kubectl get crd computeaddresses.compute.cnrm.cloud.google.com 2>/dev/null; do sleep 5; done'
      echo "Config Connector CRDs are ready!"
    EOT
  }
}


# Output the cluster endpoint for webapp deployment
output "gke_cluster_endpoint" {
  value = google_container_cluster.webapp_cluster.endpoint
  description = "GKE cluster endpoint for webapp deployment"
}

output "gke_cluster_name" {
  value = google_container_cluster.webapp_cluster.name
  description = "GKE cluster name"
}

output "config_connector_sa" {
  value = google_service_account.config_connector.email
  description = "Config Connector service account"
}

# RBAC for Cloud Deploy service account to deploy applications
resource "kubectl_manifest" "cloud_deploy_rbac_role" {
  depends_on = [google_container_cluster.webapp_cluster]

  yaml_body = <<-YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cloud-deploy-role
rules:
# Allow full access to deploy applications
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
YAML
}

resource "kubectl_manifest" "cloud_deploy_rbac_binding" {
  depends_on = [kubectl_manifest.cloud_deploy_rbac_role]

  yaml_body = <<-YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cloud-deploy-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cloud-deploy-role
subjects:
- kind: User
  name: ${google_service_account.cloud_deploy_sa.email}
  apiGroup: rbac.authorization.k8s.io
YAML
}

# Additional RBAC for Config Connector resources specifically
resource "kubectl_manifest" "cloud_deploy_config_connector_role" {
  depends_on = [kubectl_manifest.webapp_namespace]

  yaml_body = <<-YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: config-connector-deployer
  namespace: webapp-resources
rules:
- apiGroups:
  - "*"
  resources:
  - "*"
  verbs:
  - "*"
YAML
}

resource "kubectl_manifest" "cloud_deploy_config_connector_binding" {
  depends_on = [kubectl_manifest.cloud_deploy_config_connector_role]

  yaml_body = <<-YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: config-connector-deployer-binding
  namespace: webapp-resources
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: config-connector-deployer
subjects:
- kind: User
  name: ${google_service_account.cloud_deploy_sa.email}
  apiGroup: rbac.authorization.k8s.io
YAML
}