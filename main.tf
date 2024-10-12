resource "aws_vpc" "service_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "service-vpc"
  }
}

module "service_vpc" {
  source             = "./vpc"
  vpc_name           = "service_vpc"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["ap-southeast-1a"]
  public_subnets     = ["10.0.1.0/24"]
  custom_tags = {
    env           = "dev"
    managed_by_tf = true
    workspace     = "dev-workspace"
  }
}

resource "aws_subnet" "service_public_subnet" {
  vpc_id            = module.service_vpc.vpc_id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"
  depends_on        = [aws_vpc.service_vpc]
  tags = {
    Name = "service-public-subnet"
  }
}

resource "aws_internet_gateway" "service_igw" {
  vpc_id = aws_vpc.service_vpc.id
  tags = {
    Name = "service-igw"
  }
}

resource "aws_route_table" "service_rt" {
  vpc_id = aws_vpc.service_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.service_igw.id
  }

  tags = {
    Name = "service_rt"
  }
}

resource "aws_route_table_association" "service_rt_assoc" {
  subnet_id      = aws_subnet.service_public_subnet.id
  route_table_id = aws_route_table.service_rt.id
}


resource "aws_vpc" "db_vpc" {
  cidr_block = "20.0.0.0/16"
  tags = {
    Name = "db-vpc"
  }
}

resource "aws_subnet" "db_pvt_subnet" {
  vpc_id            = aws_vpc.db_vpc.id
  cidr_block        = "20.0.1.0/24"
  availability_zone = "ap-southeast-1a"
  depends_on        = [aws_vpc.db_vpc]
  tags = {
    Name = "db-pvt-subnet"
  }
}

# NAT gateway for later
resource "aws_route_table" "db_rt" {
  vpc_id = aws_vpc.db_vpc.id
  tags = {
    Name = "db_rt"
  }
}

resource "aws_route_table_association" "db_rt_assoc" {
  subnet_id      = aws_subnet.db_pvt_subnet.id
  route_table_id = aws_route_table.db_rt.id
}


# Vpc peering

resource "aws_vpc_peering_connection" "vpc_peering" {
  vpc_id      = aws_vpc.service_vpc.id
  peer_vpc_id = aws_vpc.db_vpc.id
  auto_accept = true

  tags = {
    Name : "service-db-vpc-peering"
  }
}


resource "aws_route" "service_vpc_peering_rt" {
  route_table_id            = aws_route_table.service_rt.id
  destination_cidr_block    = aws_vpc.db_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}

resource "aws_route" "db_vpc_peering_rt" {
  route_table_id            = aws_route_table.db_rt.id
  destination_cidr_block    = aws_vpc.service_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}
