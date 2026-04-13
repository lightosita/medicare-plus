environment  = "dev"
project_name = "medicare-plus"
aws_region   = "us-east-1"

vpc_cidr           = "10.1.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

public_subnet_cidrs   = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs  = ["10.1.10.0/24", "10.1.11.0/24"]
isolated_subnet_cidrs = ["10.1.20.0/24", "10.1.21.0/24"]

db_name           = "medicareplus"
db_instance_class = "db.t3.micro"
redis_node_type   = "cache.t3.micro"

app_image         = "nginx:latest"
app_cpu           = 256
app_memory        = 512
app_desired_count = 1
app_min_count     = 1
app_max_count     = 3



db_username = "medicareapp"
