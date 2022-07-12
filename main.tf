resource "kubernetes_service_account" "configure-users-sa" {
  metadata {
    name      = "configure-users-sa"
    namespace = var.project
  }
}


resource "kubectl_manifest" "configure-users-crb" {
  depends_on = [
    kubernetes_service_account.configure-users-sa
  ]
  yaml_body = <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: configure-users-rb
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: configure-users-sa
  namespace: ${var.project}
YAML 
}

resource "kubectl_manifest" "cronjob-script" {
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: cronjob-script
  namespace: ${var.project}
data:
  script.sh: |
    oc login --token=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token) --server=kubernetes.default.svc --insecure-skip-tls-verify
    set -x
    helm template rhacm-policy --set "users=$(oc get users -o json | jq -c ' .items | map(select( .identities[0] | contains("IBMid") )) | map(.metadata.name) ' | tr '[]' '{}')" | oc apply -f -
YAML
}

resource "kubectl_manifest" "cronjob" {
  depends_on = [
    kubectl_manifest.configure-users-crb,
    kubectl_manifest.cronjob-script
  ]
  yaml_body = <<YAML
apiVersion: batch/v1
kind: CronJob
metadata:
  name: users-read-only-workspace
  namespace: ${var.project}
spec:
  ## Every 5 minutes
  #schedule: "*/5 * * * *"
  ## Every minute
  schedule: "* * * * *"
  successfulJobsHistoryLimit: 0
  failedJobsHistoryLimit: 0
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: configure-users-sa
          containers:
            - name: set-permissions
              image: quay.io/aminerachyd/ro-users-k8s:0.0.7
              command:
                - /bin/sh
                - -c
                - /home/script/script.sh
              volumeMounts:
                - name: script
                  mountPath: "/home/script/"
          volumes:
            - name: script
              configMap:
                name: cronjob-script
                defaultMode: 0777
          restartPolicy: OnFailure
YAML
}
