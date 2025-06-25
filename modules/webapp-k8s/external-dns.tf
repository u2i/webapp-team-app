# External DNS for automatic DNS record management
# This watches for Service/Ingress annotations and creates DNS records automatically

# Service account for External DNS
resource "google_service_account" "external_dns" {
  project      = data.google_project.tenant_app.project_id
  account_id   = "external-dns"
  display_name = "External DNS Service Account"
  description  = "Service account for External DNS to manage DNS records"
}

# Grant DNS admin permissions on the webapp zone
resource "google_project_iam_member" "external_dns_dns_admin" {
  project = data.google_project.tenant_app.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.external_dns.email}"
}

# Workload Identity binding for External DNS
resource "google_service_account_iam_member" "external_dns_workload_identity" {
  service_account_id = google_service_account.external_dns.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${data.google_project.tenant_app.project_id}.svc.id.goog[external-dns/external-dns]"

  depends_on = [google_container_cluster.webapp_cluster]
}

# Deploy External DNS using kubectl
resource "null_resource" "deploy_external_dns" {
  triggers = {
    cluster_id = google_container_cluster.webapp_cluster.id
    sa_email   = google_service_account.external_dns.email
  }

  provisioner "local-exec" {
    command = <<-EOT
      gcloud container clusters get-credentials ${var.gke_cluster_name} \
        --region ${var.primary_region} \
        --project ${data.google_project.tenant_app.project_id}
      
      # Create namespace
      kubectl create namespace external-dns --dry-run=client -o yaml | kubectl apply -f -
      
      # Deploy External DNS
      kubectl apply -f - <<'EOF'
      apiVersion: v1
      kind: ServiceAccount
      metadata:
        name: external-dns
        namespace: external-dns
        annotations:
          iam.gke.io/gcp-service-account: ${google_service_account.external_dns.email}
      ---
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: external-dns
      rules:
      - apiGroups: [""]
        resources: ["services","endpoints","pods"]
        verbs: ["get","watch","list"]
      - apiGroups: ["extensions","networking.k8s.io"]
        resources: ["ingresses"]
        verbs: ["get","watch","list"]
      - apiGroups: [""]
        resources: ["nodes"]
        verbs: ["list"]
      - apiGroups: ["gateway.networking.k8s.io"]
        resources: ["gateways","httproutes","grpcroutes","tcproutes","tlsroutes","udproutes"]
        verbs: ["get","watch","list"]
      ---
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata:
        name: external-dns-viewer
      roleRef:
        apiGroup: rbac.authorization.k8s.io
        kind: ClusterRole
        name: external-dns
      subjects:
      - kind: ServiceAccount
        name: external-dns
        namespace: external-dns
      ---
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: external-dns
        namespace: external-dns
      spec:
        strategy:
          type: Recreate
        selector:
          matchLabels:
            app: external-dns
        template:
          metadata:
            labels:
              app: external-dns
          spec:
            serviceAccountName: external-dns
            containers:
            - name: external-dns
              image: registry.k8s.io/external-dns/external-dns:v0.14.0
              args:
              - --source=service
              - --source=ingress
              - --source=gateway-httproute
              - --source=gateway-grpcroute
              - --source=gateway-tcproute
              - --source=gateway-tlsroute
              - --source=gateway-udproute
              - --domain-filter=webapp.u2i.dev  # Only manage webapp subdomain
              - --provider=google
              - --google-project=${data.google_project.tenant_app.project_id}
              - --registry=txt
              - --txt-owner-id=webapp-cluster
              - --log-level=info
              - --policy=upsert-only  # Don't delete records on reprovisioning
              env:
              - name: GOOGLE_APPLICATION_CREDENTIALS
                value: /var/run/secrets/workload-identity/token
              volumeMounts:
              - name: wi-token
                mountPath: /var/run/secrets/workload-identity
                readOnly: true
            volumes:
            - name: wi-token
              projected:
                sources:
                - serviceAccountToken:
                    path: token
                    expirationSeconds: 3600
                    audience: https://iam.googleapis.com/projects/${data.google_project.gke_project.number}/locations/global/workloadIdentityPools/${data.google_project.tenant_app.project_id}.svc.id.goog/providers/gke-identity
      EOF
    EOT
  }

  depends_on = [
    google_container_cluster.webapp_cluster,
    google_service_account_iam_member.external_dns_workload_identity,
    null_resource.wait_for_config_connector
  ]
}

output "external_dns_instructions" {
  value = <<-EOT
    External DNS is deployed and will automatically manage DNS records for:
    - Services with annotation: external-dns.alpha.kubernetes.io/hostname
    - Ingresses with annotation: external-dns.alpha.kubernetes.io/hostname
    
    Example:
    metadata:
      annotations:
        external-dns.alpha.kubernetes.io/hostname: dev.webapp.u2i.dev
        external-dns.alpha.kubernetes.io/ttl: "300"
    
    External DNS will only manage records under: webapp.u2i.dev
  EOT
}