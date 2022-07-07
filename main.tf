resource "null_resource" "remove-self-provisioner" {
  provisioner "local-exec" {
    command = "oc login --server=${var.cluster-host} --token=${var.cluster-token} --insecure-skip-tls-verify=true && oc adm policy remove-cluster-role-from-group self-provisioner system:authenticated:oauth"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "oc adm policy add-cluster-role-to-group self-provisioner system:authenticated:oauth"
  }
}

resource "kubectl_manifest" "readonly-group" {
  depends_on = [
    null_resource.remove-self-provisioner
  ]
  yaml_body = <<YAML
apiVersion: user.openshift.io/v1
kind: Group
metadata: 
  name: ${var.group-name}
users: null
YAML
}

resource "null_resource" "add-readonly-to-projects" {
  depends_on = [
    kubectl_manifest.readonly-group
  ]
  count = length(var.projects)
  provisioner "local-exec" {
    command = "oc login --server=${var.cluster-host} --token=${var.cluster-token} --insecure-skip-tls-verify=true && oc adm policy add-role-to-group view ${var.group-name} -n ${var.projects[count.index]}"
  }
}

resource "kubernetes_service_account" "configure-users-sa" {
  metadata {
    name      = "configure-users-sa"
    namespace = var.projects[0]
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
  namespace: ${var.projects[0]}
YAML 
}

resource "kubectl_manifest" "cronjob-script" {
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: cronjob-script
  namespace: ${var.projects[0]}
data:
  script.sh: |
    oc login --token=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token) --server=kubernetes.default.svc --insecure-skip-tls-verify
    set -x
    oc patch group ${var.group-name} --patch {\"users\":$(oc get users -o json | jq -c ' .items | map(select( .identities[0] | contains("IBMid") )) | map(.metadata.name) ')}
YAML
}

resource "kubectl_manifest" "cronjob" {
  depends_on = [
    kubectl_manifest.configure-users-crb,
  ]
  yaml_body = <<YAML
apiVersion: batch/v1
kind: CronJob
metadata:
  name: users-read-only-workspace
  namespace: ${var.projects[0]}
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
              image: quay.io/aminerachyd/ibmcloud-dev:latest
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
