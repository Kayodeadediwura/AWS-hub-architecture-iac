Enterprise Hub-and-Spoke Network Topology via Terraform (AWS v5)

Project Overview

This repository automates the deployment of a secure, multi-tier enterprise network architecture inside Amazon Web Services (AWS) using Infrastructure as Code (IaC). It replaces manual console setups with predictable, declarative state management.
Architectural Features

    Hub VPC (10.0.0.0/16): Houses shared connectivity assets, managed via an AWS Transit Gateway (TGW) acting as the central cloud router.

    Finance Spoke VPC (10.1.0.0/16): Isolated workload subnet hosting business-critical data.

    HR Spoke VPC (10.2.0.0/16): Isolated human resources workload space.

    Transit Gateway Hub Routing: Replaces Azure's VNet peering. By default, VPCs attached to a Transit Gateway can route to each other unless restricted.

    Subnet Microsegmentation: Because AWS Security Groups are allow-only (stateful), an explicit cross-VPC drop rule must be enforced using a Network ACL (NACL). The NACL is programmatically bound to the Finance subnet, enforcing an explicit stateless rule blocking all inbound traffic originating from the HR VPC space (10.2.0.0/16).

