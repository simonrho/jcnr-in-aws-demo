# AWS Demo Environment for Juniper Cloud-Native Router (JCNR)

This repository provides Terraform scripts and configuration files to set up a demo environment for the Juniper Cloud-Native Router (JCNR) on AWS. It sets up AWS resources and configures JCNR in both east and west VPCs.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [AWS Resources Created](#aws-resources-created)
- [Directory Structure](#directory-structure)
- [Before start](#before-start)
- [Prerequisites](#prerequisites)
- [Demo Topology](#demo-topology)
- [Setup Guide](#setup-guide)
  - [1. Clone the Repository](#1-clone-the-repository)
  - [2. Install Necessary Tools](#2-install-necessary-tools)
  - [3. AWS Configuration](#3-aws-configuration)
    - [Obtaining AWS CLI Access Token from AWS Console](#obtaining-aws-cli-access-token-from-aws-console)
    - [Configuring AWS CLI](#configuring-aws-cli)
  - [4. Terraform Initialization and Apply](#4-terraform-initialization-and-apply)
  - [5. Labeling EKS Worker Node](#5-labeling-eks-worker-node)
  - [6. Setting up JCNR Secrets](#6-setting-up-jcnr-secrets)
    - [A. Configure `jcnr-secrets.yaml` Manually](#a-configure-jcnr-secretsyaml-manually)
    - [B. Using the Assistant Tool to Configure `jcnr-secrets.yaml`](#b-using-the-assistant-tool-to-configure-jcnr-secretsyaml)
  - [Optionally: Simplified Configuration of Node Labels and Secrets using `setup.sh`](#optionally-simplified-configuration-of-node-labels-and-secrets-using-setupsh)
  - [7. AWS Marketplace Subscription for JCNR](#7-aws-marketplace-subscription-for-jcnr)
  - [8. Helm Setup for JCNR](#8-helm-setup-for-jcnr)
  - [9. Install JCNR with Helm](#9-install-jcnr-with-helm)
  - [10. Configure JCNR and Add workloads](#10-configure-jcnr-and-add-workloads)
- [Important Configuration Consistency Note](#important-configuration-consistency-note)
- [Resource Cleanup](#resource-cleanup)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->


## AWS Resources Created

 - VPC and associated subnets.
 - VPC Peering between the VPCs.
 - EKS cluster with a single worker node.
 - Additional ENI interfaces on EKS node for JCNR data plane.
 - EC2 instances acting as L3VPN CE devices.
 - SSH key-pair for accessing EC2 instances.
 - Multus CNI driver for Kubernetes.
 - EBS CSI driver for Kubernetes.
 - DPDK environment setup DaemonSet in the worker node.
 - Kube config updated to incorporate the newly created EKS cluster.
 - Local `~/.ssh/config` updated for direct SSH access to EC2 instances running a CE workload.

## Directory Structure

```
.
├── config-east/
│   ├── charts/           # JCNR Helm chart variables for the east VPC
│   ├── config/           # JCNR and workloads configuration for east VPC
│   └── tf/               # Terraform variables for east VPC
├── config-west/
│   ├── charts/           # JCNR Helm chart variables for the west VPC
│   ├── config/           # JCNR and workloads configuration for west VPC
│   └── tf/               # Terraform variables for west VPC
├── tf-aws/               # Terraform scripts for AWS resources
├── secrets/              # K8s secrets manifest for JCNR and setup script
└── install-tools.sh      # Script to install required tools
```

## Before start 
For a smooth deployment experience, we recommend utilizing two separate machines or virtual machines (VMs) as your setup environment. This ensures that there's no overlap or confusion between the two EKS clusters and their respective Terraform operations. While the guide is crafted for Ubuntu 22.04 as the primary setup machine, other Linux distributions such as CentOS or Rocky Linux should also be compatible. macOS users can adapt this guide, though there might be minor differences in some steps.

 ## Prerequisites

 - An active AWS account to obtain the necessary AWS access token.
 - Git installed on your setup machine.
 - Basic knowledge of AWS, Kubernetes, and Terraform.
 - Familiarity with Junos, JCNR, and L3VPN concepts.


## Demo Topology
Network Topology
![Topology](./topology/demo-topology.png)

End-to-End Workload types
![Workload Types](./topology/demo-workload-types.png)


## Setup Guide

### 1. Clone the Repository

```bash
git clone https://github.com/simonrho/jcnr-in-aws-demo.git
cd jcnr-in-aws-demo
```

### 2. Install Necessary Tools

Run the provided script to install the required tools:

```bash
./install-tools.sh
```

 ### 3. AWS Configuration

 To configure the AWS Command Line Interface (CLI), you'll first need to obtain your Access Key ID and Secret Access Key from the AWS Management Console. Follow the steps below:

 #### Obtaining AWS CLI Access Token from AWS Console

 1. Sign in to the [AWS Management Console](https://aws.amazon.com/console/).

 2. Click on your username at the top right corner of the console.

 3. From the drop-down menu, choose "My Security Credentials".

 4. Under the "Access keys (access key ID and secret access key)" section, click on "Create New Access Key". This will generate a new set of credentials.

 5. You'll see a pop-up window showing your newly created Access Key ID and Secret Access Key. Click "Download .csv" to save these credentials or note them down securely. **Important:** This is the only time you'll be able to view the Secret Access Key via the AWS Console. Ensure you store it securely.

 #### Configuring AWS CLI

 Now that you have your AWS Access Key ID and Secret Access Key, you can configure AWS CLI:

 ```bash
 aws configure
 ```

 You'll be prompted to provide the following details:

 - **AWS Access Key ID:** Enter the Access Key ID from the previously downloaded .csv or the one you noted down.
 - **AWS Secret Access Key:** Enter the Secret Access Key.
 - **Default region name:** Enter your preferred AWS region (e.g., `us-east-2`).
 - **Default output format:** You can select `json`, `yaml`, `text`, or leave it blank for default.

 **Note:** Always ensure you store your AWS credentials securely and avoid exposing them in any public or insecure locations.

### 4. Terraform Initialization and Apply

Before running Terraform, copy the appropriate `variables.tf` file from the east/west config directory to the `tf-aws` directory, and then navigate to the `tf-aws` directory:



For the East VPC:

```bash
cp config-east/tf/variables.tf tf-aws/
```

For the West VPC:
```bash
cp config-west/tf/variables.tf tf-aws/
```

Now, switch to the tf-aws directory and initialize Terraform:
```bash
cd tf-aws/
terraform init

```

Apply the Terraform configurations:
```bash
terraform apply
```

### 5. Labeling EKS Worker Node 

The JCNR deployment targets EKS worker nodes with a specific label. You can manually add this label using the following command:

```bash
kubectl label nodes $(kubectl get nodes -o json | jq -r .items[0].metadata.name) key1=jcnr --overwrite
```

 **Note on DPDK Environment Setup:** 
 During the infrastructure provisioning process, Terraform is employed to automate the creation and configuration of the required AWS resources. One such resource is a daemonset service named `dpdk-env-setup`. This service is designed to set up the DPDK running environment tailored for JCNR on your AWS Elastic Kubernetes Service (EKS) nodes. 

 The `dpdk-env-setup` specifically targets worker nodes that are identified by a unique tag/label. If you wish to modify which nodes are targeted, you can adjust this tag/label specification directly in the Terraform configuration code (`variables.tf`). Furthermore, this tag/label value has significance beyond just the DPDK setup; it's also referenced during the JCNR helm chart installation, as specified in the `values.yaml` file within the JCNR helm charts.

 ### 6. Setting up JCNR Secrets

 Before you proceed with the installation of JCNR, it's crucial to configure the `jcnr-secrets.yaml` with the required credentials. There are two approaches to achieve this: Manually and using the provided Assistant Tool.

 #### A. Configure `jcnr-secrets.yaml` Manually

 1. Enter the JCNR root password and your Juniper Cloud-Native Router license file into the `secrets/jcnr-secrets.yaml` file.

 Sample contents of the `jcnr-secrets.yaml` file:

 ```yaml
 ---
 apiVersion: v1
 kind: Namespace
 metadata:
   name: jcnr
 ---
 apiVersion: v1
 kind: Secret
 metadata:
   name: jcnr-secrets
   namespace: jcnr
 data:
   root-password: <add your password in base64 format>
   crpd-license: |
     <add your license in base64 format>
 ```

 2. Encode the password and license in base64:

    - For the password:

 ```bash
 echo "YourPlainTextPassword" > rootPasswordFile
 base64 -w 0 rootPasswordFile
 ```

    - For the license:

 ```bash
 base64 -w 0 licenseFile
 ```

 3. Copy the base64 outputs and paste them into the `secrets/jcnr-secrets.yaml` file at the respective places.

 4. Apply the secrets to Kubernetes:

 ```bash
 kubectl apply -f secrets/jcnr-secrets.yaml
 ```

 **NOTE:** Without the proper base64-encoded license file and JCNR root password in the `secrets.yaml` file, the cRPD Pod will remain in `CrashLoopBackOff` state.


 #### B. Using the Assistant Tool to Configure `jcnr-secrets.yaml`

 For a more streamlined approach, use the `build-secrets.sh` script. Before you start, create two files: `jcnr-root-password.txt` (JCNR root password) and `jcnr-license.txt` (JCNR license). These files are **user-provided** and are not part of the git cloned files.

 1. Run the script:

 ```bash
 ./build-secrets.sh <path-to-root-password-file> <path-to-jcnr-license-file>
 ```

 Example:

 ```bash
 ./build-secrets.sh jcnr-root-password.txt jcnr-license.txt
 ```

 2. After execution, the generated `jcnr-secrets.yaml` will be in the current directory. Verify with:

 ```bash
 ls
 cat jcnr-secrets.yaml
 ```

 3. Apply the secrets to Kubernetes:

 ```bash
 kubectl apply -f jcnr-secrets.yaml
 ```

 **NOTE:** Ensure your license file is obtained from your account team and integrated correctly. Otherwise, the cRPD Pod might face issues.



### Optionally: Simplified Configuration of Node Labels and Secrets using `setup.sh`

 For those looking to simplify and automate the processes described in Sections 5 and 6, the provided `setup.sh` script under the `secrets` directory offers an all-in-one solution. This script serves two main purposes:

 1. **JCNR Secrets Configuration:** It automates the creation of the `jcnr-secrets.yaml` file, ensuring the JCNR secrets (license and root password) are appropriately set.
 2. **Labeling the EKS Worker Node:** It ensures that the necessary label (used for targeting by the DPDK environment setup) is added to the EKS worker node.

 To utilize this streamlined approach, follow the steps below:

 ```
 cd ~/demo/secrets
 ```

 2. Execute the `setup.sh` script:

 ```
./setup.sh
Reading root password from jcnr-root-password.txt
Reading license key from jcnr-license.txt
Creating jcnr-secrets.yaml file
Applying JCNR secrets and namespace
namespace/jcnr unchanged
secret/jcnr-secrets configured
Enter label in format key=value (default is key1=jcnr):
Adding label to eks worker nodes
```

 Upon execution, the script will:

 - Create and apply the `jcnr-secrets.yaml` file with the JCNR secrets.
 - Add the `key1=jcnr` label to your EKS worker nodes, making them identifiable for the JCNR deployment.

 **NOTE:** While the `setup.sh` script offers convenience, it's essential to understand the underlying manual steps (as detailed in Sections 5 & 6) to troubleshoot potential issues or customize configurations further.



 ### 7. AWS Marketplace Subscription for JCNR

 Before you can proceed with Helm setup and pull JCNR helm charts, you need to visit the AWS Marketplace and subscribe to the JCNR container product.

 1. Navigate to the [AWS Marketplace](https://aws.amazon.com/marketplace/).
 2. In the search bar, type "JCNR" and search.
 3. Click on the relevant product from the search results.
 4. Go through the product details and click on the "Subscribe" or "Continue to Subscribe" button.
 5. Complete the subscription process as prompted.

 **Note:** Without this subscription, you won't have access to the JCNR helm charts and package images from the ECR (Elastic Container Registry). It's essential to ensure that the subscription is successful before proceeding further.

 ### 8. Helm Setup for JCNR

 First, ensure that you are authenticated with AWS. Helm will use your AWS credentials to pull the JCNR helm charts from the AWS Marketplace.

 Login to your AWS account via Helm:

 ```bash
 export HELM_EXPERIMENTAL_OCI=1

 aws ecr get-login-password \
     --region us-east-1 | helm registry login \
     --username AWS \
     --password-stdin 709825985650.dkr.ecr.us-east-1.amazonaws.com
 ```

 Now, pull and untar the JCNR helm charts:

 ```bash
 helm pull oci://709825985650.dkr.ecr.us-east-1.amazonaws.com/juniper-networks/jcnr --version 23.2.0
 ```

 Untar the JCNR helm charts tar file:

 ```bash
 tar zxvf jcnr-23.2.0.tgz 
 ```

 After successfully creating all AWS resources, install the JCNR with the helm charts downloaded from the AWS marketplace.

 ---

### 9. Install JCNR with Helm

After successfully creating all AWS resources, install the JCNR with the helm charts downloaded from the AWS marketplace.

Use the `values.yaml` from the appropriate charts directory of `config-east/charts` or `config-west/charts`.

Now, switch to the jcnr directory and install jcnr:

For the East VPC:

```bash
cd jcnr
cp ../config-east/charts/values.yaml ./values.yaml
```

For the West VPC:

```bash
cd jcnr
cp ../config-west/charts/values.yaml ./values.yaml
```

After setting the correct values, you can proceed with the JCNR installation using Helm:

```bash
helm install jcnr .
```
Wait for a few minutes for the JCNR pods and services to be deployed. Once done, you can check the status using:

```bash
helm ls
kubectl get pods -n jcnr
kubectl get pods -n contrail
```

 ### 10. Configure JCNR and Add workloads 

 Setting up the JCNR (Junos Cloud-Native Router) involves two primary tasks: configuring the JCNR router itself and adding the corresponding workloads. Workloads come in two flavors: Kubernetes pods that simulate CE (Customer Equipment) devices and EC2 instances. 

 1. Setting up JCNR Configurations

 
 ```bash
 kubectl exec -it -n jcnr kube-crpd-worker-sts-0 -c kube-crpd-worker -- bash
 ```

 After the Juniper cRPD banner appears:

 ```plaintext
           Containerized Routing Protocols Daemon (CRPD)
 Copyright (C) 2020-2023, Juniper Networks, Inc. All rights reserved.
 ```

 Access the Junos CLI with `cli`, then enter the configuration mode using `edit`.

 ```bash
 root@ip-172-16-1-77:/# cli
 root@ip-172-16-1-77.us-west-2.compute.internal> edit
 ```

 Within this mode, you can copy and paste the desired JCNR configurations directly from the respective `.conf` files found within the `config-east` or `config-west` directories.

 **Informational:** The specific hostname (`ip-172-16-1-77` in the example) of your EKS node may differ depending on how AWS has provisioned your EKS cluster. Always verify the correct hostname of your EKS node when accessing the CLI.

2. **For Kubernetes Pods:** Kubernetes configurations use `.yaml` files located in the `config-east` and `config-west` directories. When you deploy these configurations using `kubectl apply`, the system triggers the JCNR CNI driver. This driver dynamically builds the VRF configuration, adds it, and commits it to the cRPD of JCNR.

 Deploy the Kubernetes workloads with:

 ```bash
 kubectl apply -f config-east/config/red1.yaml
 kubectl apply -f config-west/config/blue1.yaml
 ```

 **Note:** The `kubectl apply` command is a native Kubernetes approach to create a workload. Once it's executed, it activates the JCNR CNI driver, setting up the VRF configurations dynamically.


 3. **For EC2 Instances:** For workloads that utilize EC2 instances, the connection to JCNR happens through regular ENI interfaces & VPC subnets. In these scenarios, there's no JCNR CNI involvement. Thus, manual VRF configurations must be added to the JCNR, which are specified in the `red*.conf` and `blue*.conf` files.

 ## Important Configuration Consistency Note

 When deploying JCNR and setting up the DPDK environment on your EKS worker nodes, consistency across specific configurations is paramount. Ensure that:

 1. The `nodeAffinity` configuration in `values.yaml` located in both `config-east/charts` & `config-west/charts` directories is set as:
 ```yaml
  nodeAffinity:
  - key: key1
    operator: In
    values:
    - jcnr
 ```

 2. The `node_selector` variable in `variables.yaml` from the `config-east/config` & `config-west/config` folders aligns with:
 ```hcl
 variable "node_selector" {
   description = "Node selector key-value for the Kubernetes DaemonSet adding DPDK env setup in target nodes"
   type        = map(string)
   default     = {
     "key1" = "jcnr"
   }
 }
 ```

 3. The label added to your EKS worker nodes via the command 
 ```
 kubectl label nodes $(kubectl get nodes -o json | jq -r .items[0].metadata.name) "key1=jcnr" --overwrite 
 ```
 matches the above configurations.

 Ensuring consistency across these configurations guarantees that the DPDK environment setup and JCNR installation target the intended EKS worker nodes. Inconsistencies can lead to deployment errors or undesired behavior.


## Resource Cleanup
To securely dismantle all AWS components and the JCNR deployment, follow these steps:

```bash
cd tf-aws/
terraform destroy
```

Should you encounter the Error: context deadline exceeded while removing AWS resources, simply execute `terraform destroy` once more to ensure complete resource removal.