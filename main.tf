################################################################################
# VPC
################################################################################

resource "aws_vpc" "myVPC" {
  cidr_block                       = var.cidr
  enable_dns_hostnames             = var.enable_dns_hostnames
  enable_dns_support               = var.enable_dns_support
  tags = {
    Name = var.vpc_name
  }
}

###############################################################################
# Internet Gateway
###############################################################################

resource "aws_internet_gateway" "myIGW" {

  vpc_id = aws_vpc.myVPC.id
  tags = {
    "Name" = var.igw_tag
  }
}

################################################################################
# Public subnet
################################################################################

resource "aws_subnet" "public_subnet_1" {
  vpc_id                          = aws_vpc.myVPC.id
  cidr_block                      = var.public_subnets_cidr_1
  availability_zone               = data.aws_availability_zones.available_1.names[0]
  map_public_ip_on_launch         = var.map_public_ip_on_launch

  tags = {
   Name = var.public_subnet_tag_1
  }
}
resource "aws_subnet" "public_subnet_2" {
  vpc_id                          = aws_vpc.myVPC.id
  cidr_block                      = var.public_subnets_cidr_2
  availability_zone               = data.aws_availability_zones.available_1.names[1]
  map_public_ip_on_launch         = var.map_public_ip_on_launch

  tags = {
   Name = var.public_subnet_tag_2
  }
}

################################################################################
# Publiс routes
################################################################################

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.myVPC.id
  tags = {
    Name = var.public_route_table_tag
  }
}
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.myIGW.id
}


################################################################################
# Route table association with subnets
################################################################################

resource "aws_route_table_association" "public_route_table_association_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}
resource "aws_route_table_association" "public_route_table_association_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}


###############################################################################
# Security Group
###############################################################################

resource "aws_security_group" "sg" {
  name        = "tcw_security_group"
  description = "Allow all inbound traffic"
  vpc_id      = aws_vpc.myVPC.id

  ingress = [
    {
      description      = "All traffic"
      from_port        = 0    # All ports
      to_port          = 0    # All Ports
      protocol         = "-1" # All traffic
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = null
      prefix_list_ids  = null
      security_groups  = null
      self             = null
    }
  ]

  egress = [
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      description      = "Outbound rule"
      prefix_list_ids  = null
      security_groups  = null
      self             = null
    }
  ]

  tags = {
    Name = "tcw_security_group"
  }
}

#######################################################################################################
#Creating IAM
#######################################################################################################
resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_service" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster.name
}

######################################################################################################
#Creating EKS
######################################################################################################

resource "aws_eks_cluster" "eks_cluster" {
  name = "My_eks_Cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  vpc_config {
    subnet_ids = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  }
  depends_on = [aws_iam_role_policy_attachment.eks_cluster]
}

