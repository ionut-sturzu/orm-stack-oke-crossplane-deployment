# orm-stack-oke-crossplane

## Introduction

[Crossplane provider for OCI](https://github.com/oracle-samples/crossplane-provider-oci) gives the posibility to create terrafrom resources from OKE environment without the need to go outside the kuberenetes environment. In this automation we install all the required components and start the provider automatically. The provider will be configured automatically with the required credentials and resources can be directly createad.

## Getting started

This stack deploys an OKE cluster with one nodepool:
- one nodepool with flexible shapes
- one operator/bastion instance from where the OKE cluster will be accessed
- one OCI Registry which will be used to push the crossplane provider image

And several required applications:
- Git 2.25 (recommended)
- Terraform 1.4.6 (recommended)
- Go 1.19.x (required)
- Goimports
- Kubectl 5.0.1 (recommended)
- Helm 3.11.2 (recommended)
- Docker 20.10.20 (recommended)
- Crossplane 1.10 (recommended)


**Note:** The cluster will have an operator/bastion server on which the required applications will be installed and the crossplane image will be build and pushed to OCI Registry.

# Prerequisites
1. Auth Token
- In order to run the automation you will need to obtain an Auth token with at least 5 minutes before running it. 
- Do obtain the Auth Token navigate to OCI console to your user. Click on Auth token on the left side collumn and generate token. 
- You will need to provide the token to configure the **ocir_auth_token** variable
https://docs.oracle.com/en-us/iaas/Content/Registry/Tasks/registrygettingauthtoken.htm

2. Tenanacy namespace
- Navigate to Tenancy details and under Object storage settings, there is Object storage namespace. 
- You will need the tenanacy namespace in order to create an OCI Registry that will be used to start the crossplane and to be able to have a correct OCI Registry user.

3. OCI Registry user
- Enter your username in the format <tenancy-namespace>/<username>, where <tenancy-namespace> is the auto-generated Object Storage namespace string of your tenancy (as shown on the Tenancy Information page). For example, ansh81vru1zp/jdoe@acme.com. If your tenancy is federated with Oracle Identity Cloud Service, use the format <tenancy-namespace>/oracleidentitycloudservice/<username>.
- You will need to create this user to configure the **ocir_username** variable.

4. OCI Private key content
- Run the following command on the environment where you have the OCI private key:
```
awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' <same path to key file as your OCI CLI config>
```
- Copy the resulted content that will be required to configure the **private_key_content** variable.
- This is used for the crossplane provider login to OCI.

## How to run the automation
 - Upload the stack to Resorce Manager
 - Congfigure the required variables
 - Run Apply

### Local deployment

- Create a file called `terraform.auto.tfvars` with the required values.

```
# ORM injected values

tenancy_ocid         = "ocid1.tenancy.oc1.."            # Get this from OCI Console (after logging in, go to top-right-most menu item and click option "Tenancy: <your tenancy name>").
user_ocid            = "ocid1.user.oc1.."               # Get this from OCI Console (after logging in, go to top-right-most menu item and click option "My profile").
fingerprint          = "4d:d3:13:98:ec:.."     # The fingerprint can be gathered from your user account. In the "My profile page, click "API keys" on the menu in left hand side.
private_key_path     = "" # This is the full path on your local system to the API signing private key.
private_key_password = ""                          # This is the password that protects the private key, if any.
region               = ""  


compartment_ocid  = "ocid1.compartment.oc1.."

# OKE Terraform module values
create_iam_resources     = false
create_iam_tag_namespace = false
ssh_public_key           = ""

## NodePool with non-GPU shape is created by default with size 1
simple_np_flex_shape   = { "instanceShape" = "VM.Standard.E4.Flex", "ocpus" = 2, "memory" = 12 }

## NodePool with GPU shape is created by default with size 0
gpu_np_size  = 0
gpu_np_shape = "VM.GPU.A10.1"

## OKE Deployment values
cluster_name           = "oke"
vcn_name               = "oke-vcncrossplane"
compartment_id         = "ocid1.compartment.oc1.."

#OCIR & Crossplane login values
registry_display_name  = "tfcrossplane"
ocir_auth_token = ""
ocir_username = ""
private_key_content = ""
```

- Uncomment the provier.tf with tenancy, user ocid, private_key_path, fingerprint
- Execute the commands

```
terraform init
terraform plan
terraform apply
```

# Deploy resources using Crossplane OCI provider
After the deployment is completed go to outputs and get the ssh command to be able to login into the operator instance where the Crossplane OCI provider has been installed.
To create resources in OCI you can look at the examples from here: https://github.com/oracle-samples/crossplane-provider-oci/tree/main/examples 
Create an .yaml file with the content for the resource that you want to deploy it and just run k apply -f name_of_file.yaml
The resource will be created and you can see it the provider logs located in /home/opc/make_run.log

## Known Issues
- No Known Issues