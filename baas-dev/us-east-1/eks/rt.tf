resource "aws_route_table" "eks_node_rt" {
  vpc_id = local.baas_dev_vpc_us.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = local.baas_dev_vpc_us.natgw_ids[0]
  }

  tags = module.naming.tags
}

resource "aws_route_table" "eks_cp_rt" {
  vpc_id = local.baas_dev_vpc_us.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = local.baas_dev_vpc_us.natgw_ids[0]
  }

  route {
    cidr_block         = local.baas_shared_vpc_us_cidr_block
    transit_gateway_id = local.tgw_id
  }

  tags = module.naming.tags
}

resource "aws_route_table_association" "eks_node_rt_association" {
  for_each       = { for k, v in module.eks_node_subnets.private_subnet_ids : k => v }
  subnet_id      = each.value
  route_table_id = aws_route_table.eks_node_rt.id

  depends_on = [aws_route_table.eks_node_rt, module.eks_node_subnets]
}

resource "aws_route_table_association" "eks_cp_rt_association" {
  for_each       = { for k, v in module.eks_cp_subnets.private_subnet_ids : k => v }
  subnet_id      = each.value
  route_table_id = aws_route_table.eks_cp_rt.id

  depends_on = [aws_route_table.eks_cp_rt, module.eks_cp_subnets]
}
