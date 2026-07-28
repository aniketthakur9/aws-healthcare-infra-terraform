# ec2 
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_key_pair" "health_app" {
  key_name   = "${var.project_name}-${var.environment}-${random_id.suffix.hex}-key"
  public_key = file(var.ssh_public_key_path)

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_instance" "health_app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.health_app.id]
  key_name               = aws_key_pair.health_app.key_name

  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data_base64 = base64gzip(templatefile("${path.module}/user_data.sh", {
    index_html             = file("${path.module}/website/index.html")
    doctors_html           = file("${path.module}/website/doctors.html")
    nurses_html            = file("${path.module}/website/nurses.html")
    patients_html          = file("${path.module}/website/patients.html")
    app_py                 = file("${path.module}/admin-dashboard/app.py")
    admin_index_html       = file("${path.module}/admin-dashboard/templates/index.html")
    admin_add_patient_html = file("${path.module}/admin-dashboard/templates/add_patient.html")
    admin_api_url          = "3.148.170.111"
    dynamodb_table         = "${var.project_name}-patients"
    s3_bucket              = aws_s3_bucket.logs.id
    aws_region             = var.aws_region
    sns_topic_arn = data.aws_sns_topic.alerts.arn
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp2"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-health-app"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}