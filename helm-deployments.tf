# Copyright (c) 2022, 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  deploy_from_operator = var.create_operator_and_bastion
  deploy_from_local    = alltrue([!local.deploy_from_operator, var.control_plane_is_public])
}

data "oci_containerengine_cluster_kube_config" "kube_config" {
  count = local.deploy_from_local ? 1 : 0

  cluster_id = module.oke.cluster_id
  endpoint   = "PUBLIC_ENDPOINT"
}

module "crossplane" {
  count  = var.deploy_crossplane ? 1 : 0
  source = "./helm-module"

  bastion_host    = module.oke.bastion_public_ip
  bastion_user    = var.bastion_user
  operator_host   = module.oke.operator_private_ip
  operator_user   = var.bastion_user
  ssh_private_key = tls_private_key.stack_key.private_key_openssh

  deploy_from_operator = local.deploy_from_operator
  deploy_from_local    = local.deploy_from_local

  deployment_name     = "crossplane"
  helm_chart_name     = "crossplane"
  namespace           = "default"
  helm_repository_url = "https://charts.crossplane.io/stable"
  pre_deployment_commands = [
    "echo 'export PATH=$PATH:~/go/bin:/usr/local/go/bin' >> ~/.bashrc",
    "echo 'export OCI_CLI_AUTH=instance_principal' >> ~/.bashrc",
    "echo 'export GOPATH=~/go' >> ~/.bashrc",
    "export GOPATH=~/go",
    "export PATH=$PATH:~/go/bin:/usr/local/go/bin",
    "source ~/.bashrc",
    "sudo yum install -y yum-utils",
    "sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo",
    "sudo yum -y install terraform",
    "sudo wget https://go.dev/dl/go1.19.10.linux-amd64.tar.gz",
    "sudo tar -C /usr/local -xzf go1.19.10.linux-amd64.tar.gz",
    "go install golang.org/x/tools/cmd/goimports@v0.23.0",
    "sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo",
    "sudo dnf remove -y runc",
    "sudo dnf install -y docker-ce --nobest",
    "sudo usermod -aG docker opc",
    "sudo systemctl enable docker.service",
    "sudo systemctl start docker.service",
    "sudo chmod 666 /var/run/docker.sock",
    "curl -sL https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh | sh",
    "sudo mv crossplane /usr/local/bin",
    "mkdir -p $GOPATH",
    "mkdir -p $GOPATH/src",
    "mkdir -p $GOPATH/src/github.com",
    "mkdir -p $GOPATH/src/github.com/crossplane-providers",
    "cd $GOPATH/src/github.com/crossplane-providers",
    "git clone https://github.com/oracle-samples/crossplane-provider-oci.git",
    "cd $GOPATH/src/github.com/crossplane-providers/crossplane-provider-oci",
    "sed -i 's/^PLATFORMS ?=.*/PLATFORMS ?= linux_amd64/' Makefile",
    "sed -i 's/^UP_VERSION = v0.14.0/UP_VERSION = v0.28.0/' Makefile",
    "make build.all",
    "make generate",
    "kubectl apply -f package/crds",
    "nohup make run > /home/opc/make_run.log 2>&1 &",
    "cd ./_output/xpkg/linux_amd64",
    "docker login ${lower(data.oci_identity_region_subscriptions.test_region_subscriptions.region_subscriptions[0].region_key)}.ocir.io -u '${var.ocir_username}' -p '${var.ocir_auth_token}'", #'ocisateam/oracleidentitycloudservice/ionut.sturzu@oracle.com' -p 'x9BLa)6>{1TcFto7i-AH'", #user si token aici poate gasec
    "crossplane xpkg push -f ./* ${lower(data.oci_identity_region_subscriptions.test_region_subscriptions.region_subscriptions[0].region_key)}.ocir.io/${oci_artifacts_container_repository.test_container_repository.namespace}/${oci_artifacts_container_repository.test_container_repository.display_name}:latest",
    "mkdir ~/crossplane_yamls",
    "cd ~/crossplane_yamls",
    "kubectl create secret docker-registry ocirauth --namespace default --docker-server=${lower(data.oci_identity_region_subscriptions.test_region_subscriptions.region_subscriptions[0].region_key)}.ocir.io --docker-username='${var.ocir_username}' --docker-password='${var.ocir_auth_token}'",
  ]

  deployment_extra_args = []
  post_deployment_commands = [
  <<-EOF
    cat <<YAML | tee ~/crossplane_yamls/provider.yaml
    apiVersion: pkg.crossplane.io/v1
    kind: Provider
    metadata:
      name: crossplane-provider-oci
      namespace: default
    spec:
      package: ${lower(data.oci_identity_region_subscriptions.test_region_subscriptions.region_subscriptions[0].region_key)}.ocir.io/${oci_artifacts_container_repository.test_container_repository.namespace}/${oci_artifacts_container_repository.test_container_repository.display_name}:latest
      packagePullSecrets:
        - name: ocirauth
    YAML
  EOF
  ,
  "kubectl apply -f ~/crossplane_yamls/provider.yaml",
  <<-EOF
    cat <<YAML | tee ~/crossplane_yamls/secret.yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: oci-creds
      namespace: default
    type: Opaque
    stringData:
      # credentials must match corresponding values of your OCI CLI config file
      # https://docs.oracle.com/en-us/iaas/Content/API/Concepts/sdkconfig.htm
      #
      # Set either private_key_path or private_key according to how your OCI provider runs.
      #
      # 'private_key_path' - optional attribute that only works with locally running OCI provider via 'make run'.
      #  Value is path of 'key_file' in your OCI CLI config.
      #
      # 'private_key' -  required attribute when OCI provider runs in k8s. This also works with locally running OCI provider via 'make run'.
      #  Value is content of key file that can be extracted by running the command below.
      # awk ‘NF {sub(/\r/, “”); printf “%s\\n”,$0;}’ <same path to key file as your OCI CLI config> | pbcopy
      credentials: |
        {
          "tenancy_ocid": "${var.tenancy_ocid}",
          "user_ocid": "${var.current_user_ocid}",
          "private_key_path": "",
          "private_key": "${var.private_key_content}",
          "fingerprint": "${var.fingerprint}",
          "region": "${var.region}"
        }
    YAML
  EOF
  ,
  "kubectl apply -f ~/crossplane_yamls/secret.yaml",
  <<-EOF
    cat <<YAML | tee ~/crossplane_yamls/providerconfig.yaml
    apiVersion: oci.upbound.io/v1beta1
    kind: ProviderConfig
    metadata:
      name: default
    spec:
      credentials:
        source: Secret
        secretRef:
          name: oci-creds
          namespace: default
          key: credentials
    YAML
  EOF
  ,
  "kubectl apply -f ~/crossplane_yamls/providerconfig.yaml"
  ]

  helm_template_values_override = templatefile("${path.root}/helm-values-templates/crossplane.yaml.tpl",{})
  helm_user_values_override = try(base64decode(var.crossplane_user_values_override), var.crossplane_user_values_override)

  kube_config = one(data.oci_containerengine_cluster_kube_config.kube_config.*.content)

  depends_on = [module.oke, oci_artifacts_container_repository.test_container_repository]
}