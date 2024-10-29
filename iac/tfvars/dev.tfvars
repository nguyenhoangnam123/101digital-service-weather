environment="dev"
region="us-east-1"
# eks node group tier
managed_node_group_instance_types=["t2.micro", "t2.small", "t2.medium"]
default_managed_node_group_instance_type=["t2.small"]
default_managed_node_group_capacity_type="SPOT"
# service-weather resources
mem_requests="128Mi"
mem_limits="256Mi"
cpu_requests="100m"
cpu_limits="250m"
