# Create VPC using terraform-aws-modules/vpc/aws module
module "networking" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name                 = "${var.project_name}-vpc"
  cidr                 = var.vpc_cidr
  azs                  = var.azs
  public_subnets       = var.public_subnets
  private_subnets      = var.private_subnets
  enable_nat_gateway   = true
  enable_dns_hostnames = true
  single_nat_gateway   = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

# Security group for EKS control plane
resource "aws_security_group" "eks_cluster_sg" {
  name        = "${var.project_name}-eks-cluster-sg"
  description = "Security group for EKS control plane"
  vpc_id      = module.networking.vpc_id

  ingress {
    description = "Allow inbound HTTPS traffic from worker nodes to control plane"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Allow HTTP traffic from worker nodes to control plane"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name       = "${var.project_name}-eks-cluster-sg"
    Project    = var.project_name
    Kubernetes = "cluster"
  }
}

# Security group for EKS worker nodes
resource "aws_security_group" "eks_worker_sg" {
  name        = "${var.project_name}-eks-worker-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = module.networking.vpc_id

  ingress {
    description = "Allow pod-to-pod communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description = "Allow control plane to communicate with worker nodes"
    from_port   = 1025
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name       = "${var.project_name}-eks-worker-sg"
    Project    = var.project_name
    Kubernetes = "worker"
  }
}

