# tf-aws-vpc-baseline

A reusable Terraform module that provisions a production-ready AWS VPC network foundation — designed to be the dependency anchor for all future infrastructure labs (EKS, EC2, RDS, ECS).

## Architecture

                    AWS Region (us-east-1)
    ┌──────────────────────────────────────────────┐
    │               VPC  10.0.0.0/16               │
    │                                              │
    │   ┌─────────────────────────────────────┐    │
    │   │         Internet Gateway (IGW)      │    │
    │   └──────────────┬──────────────────────┘    │
    │                  │                           │
    │   ┌──────────────▼──────────────────────┐    │
    │   │          Public Route Table         │    │
    │   │        0.0.0.0/0 → IGW              │    │
    │   └────────┬─────────────────┬──────────┘    │
    │            │                 │               │
    │   ┌────────▼──────┐ ┌────────▼──────┐        │
    │   │ Public Subnet │ │ Public Subnet │        │
    │   │  10.0.1.0/24  │ │  10.0.2.0/24  │        │
    │   │    AZ: a      │ │    AZ: b      │        │
    │   │  [NAT GW+EIP] │ │               │        │
    │   └────────┬──────┘ └───────────────┘        │
    │            │                                 │
    │   ┌────────▼────────────────────────────┐    │
    │   │         Private Route Table         │    │
    │   │        0.0.0.0/0 → NAT GW           │    │
    │   └────────┬─────────────────┬──────────┘    │
    │            │                 │               │
    │   ┌────────▼──────┐ ┌────────▼──────┐        │
    │   │Private Subnet │ │Private Subnet │        │
    │   │ 10.0.10.0/24  │ │ 10.0.20.0/24  │        │
    │   │    AZ: a      │ │    AZ: b      │        │
    │   └───────────────┘ └───────────────┘        │
    └──────────────────────────────────────────────┘



### What Gets Created

| Resource | Count | Purpose |
|---|---|---|
| VPC | 1 | Isolated network with CIDR `10.0.0.0/16` |
| Public Subnets | 2 (one per AZ) | Host internet-facing resources; auto-assign public IPs |
| Private Subnets | 2 (one per AZ) | Host backend services with no direct internet exposure |
| Internet Gateway | 1 | Enables inbound/outbound internet for public subnets |
| NAT Gateway + EIP | 1 (optional) | Allows private subnets to reach internet (outbound only) |
| Route Tables | 2 | Public → IGW; Private → NAT GW |
| Route Table Associations | 4 | Links each subnet to its correct route table |

### Traffic Flow

- **Public subnets** → traffic routes through the **Internet Gateway** — resources are directly reachable from the internet.
- **Private subnets** → outbound traffic routes through the **NAT Gateway** (in public subnet AZ-a) — resources can call out but are not reachable inbound.
- NAT Gateway can be **disabled** (`enable_nat_gateway = false`) to save ~$32/month in dev environments.


```
terraform init
terraform validate
terraform plan
terraform apply
```

⚠️ Cleanup: NAT Gateway costs ~$0.045/hr. Run terraform destroy when done.