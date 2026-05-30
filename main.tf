# 1. Provider and Global Tags
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform-IaC"
      Owner       = "Enterprise-Cloud-Migration"
    }
  }
}

# 2. Deploy the Central Hub VPC & Transit Gateway
resource "aws_vpc" "hub" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "vpc-uk-hub"
  }
}

resource "aws_ec2_transit_gateway" "tgw" {
  description = "Central Hub Transit Gateway"
  tags = {
    Name = "tgw-uk-central-hub"
  }
}

# 3. Deploy Spoke-A (Finance Department)
resource "aws_vpc" "spoke_a" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "vpc-uk-spoke-finance"
  }
}

resource "aws_subnet" "finance_subnet" {
  vpc_id            = aws_vpc.spoke_a.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "sub-finance-production"
  }
}

# 4. Deploy Spoke-B (HR Department)
resource "aws_vpc" "spoke_b" {
  cidr_block           = "10.2.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "vpc-uk-spoke-hr"
  }
}

resource "aws_subnet" "hr_subnet" {
  vpc_id            = aws_vpc.spoke_b.id
  cidr_block        = "10.2.1.0/24"
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "sub-hr-production"
  }
}

# 5 & 6. Connect Spokes to Hub via Transit Gateway Attachments
resource "aws_ec2_transit_gateway_vpc_attachment" "hub_attachment" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.hub.id
  subnet_ids         = [] # Note: In production, create/pass dedicated TGW subnets here
}

resource "aws_ec2_transit_gateway_vpc_attachment" "finance_attachment" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.spoke_a.id
  subnet_ids         = [aws_subnet.finance_subnet.id]
}

resource "aws_ec2_transit_gateway_vpc_attachment" "hr_attachment" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.spoke_b.id
  subnet_ids         = [aws_subnet.hr_subnet.id]
}

# Route Tables to send cross-VPC traffic through the TGW
resource "aws_route_table" "finance_rt" {
  vpc_id = aws_vpc.spoke_a.id

  route {
    cidr_block         = "10.0.0.0/8" # Sends all internal 10.x.x.x traffic to TGW
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }
  tags = { Name = "rt-finance" }
}

resource "aws_route_table_association" "finance_assoc" {
  subnet_id      = aws_subnet.finance_subnet.id
  route_table_id = aws_route_table.finance_rt.id
}

resource "aws_route_table" "hr_rt" {
  vpc_id = aws_vpc.spoke_b.id

  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }
  tags = { Name = "rt-hr" }
}

resource "aws_route_table_association" "hr_assoc" {
  subnet_id      = aws_subnet.hr_subnet.id
  route_table_id = aws_route_table.hr_rt.id
}

# 7. Security Layer: Prevent HR from talking directly to Finance Subnet

# AWS Network ACL (NACL) - Subnet level stateless firewall (closest mapping to Azure NSG logic)
resource "aws_network_acl" "finance_nacl" {
  vpc_id     = aws_vpc.spoke_a.id
  subnet_ids = [aws_subnet.finance_subnet.id]

  # RULE 100: Deny HR Lateral Movement
  ingress {
    protocol   = "-1" # All protocols
    rule_no    = 100
    action     = "deny"
    cidr_block = "10.2.0.0/16" # HR VPC CIDR
    from_port  = 0
    to_port    = 0
  }

  # RULE 200: Allow all other internal/valid traffic
  ingress {
    protocol   = "-1"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # NACLs are stateless, so we must explicitly allow outbound traffic
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "nacl-finance-security-core"
  }
}