provider "aws" {
  region = var.aws_region
}


resource "aws_vpc" "ecs_vpc" {

  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "ecs-vpc"
  }
}

resource "aws_subnet" "ecs_subnet" {
  count             = var.az_count
  cidr_block        = cidrsubnet(aws_vpc.ecs_vpc.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = aws_vpc.ecs_vpc.id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.ecs_vpc.id
}

# note that there is a main route table hat automatically comes with any VPC.
# It controls the routing for all subnets that are not explicitly associated
# with any other route table.
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.ecs_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "route_table_association" {
  count          = var.az_count
  subnet_id      = element(aws_subnet.ecs_subnet.*.id, count.index)
  route_table_id = aws_route_table.route_table.id
}

data "aws_availability_zones" "available" {
  state = "available"
}
