environment="prod"
region="us-east-1"
# eks node group tier
managed_node_group_instance_types=["c3.large", "c4.large", "c5.large"]
default_managed_node_group_instance_type=["c3.large"]
default_managed_node_group_capacity_type="ON_DEMAND"
# service-weather resources
mem_requests="256Mi"
mem_limits="1Mi"
cpu_requests="1"
cpu_limits="1"