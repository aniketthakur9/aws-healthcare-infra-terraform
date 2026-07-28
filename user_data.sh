#!/bin/bash
set -xe
exec > /var/log/user-data.log 2>&1

# ── System update ─────────────────────────────────────────────────────────────
yum update -y

# ── Install Nginx (Amazon Linux 2) ────────────────────────────────────────────
amazon-linux-extras install nginx1 -y
systemctl start nginx
systemctl enable nginx

# ── Fetch EC2 Public IP (runtime) ─────────────────────────────────────────────
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
ADMIN_API_URL="http://$PUBLIC_IP:5000"

# ── Write website files ───────────────────────────────────────────────────────
cat > /usr/share/nginx/html/index.html << HTMLEOF
${index_html}
HTMLEOF

cat > /usr/share/nginx/html/doctors.html << HTMLEOF
${doctors_html}
HTMLEOF

cat > /usr/share/nginx/html/nurses.html << HTMLEOF
${nurses_html}
HTMLEOF

# FIX: Write patients.html first, then replace the placeholder with real EC2 IP
cat > /usr/share/nginx/html/patients.html << HTMLEOF
${patients_html}
HTMLEOF

# Replace the Terraform-injected localhost placeholder with the real public IP
sed -i "s|http://localhost:5000|$ADMIN_API_URL|g" /usr/share/nginx/html/patients.html

systemctl restart nginx

# ── Install Python & Flask ────────────────────────────────────────────────────
yum install -y python3 python3-pip

mkdir -p /opt/admin-dashboard/templates

# ── Flask app files ───────────────────────────────────────────────────────────
cat > /opt/admin-dashboard/app.py << PYEOF
${app_py}
PYEOF

cat > /opt/admin-dashboard/templates/index.html << HTMLEOF
${admin_index_html}
HTMLEOF

cat > /opt/admin-dashboard/templates/add_patient.html << HTMLEOF
${admin_add_patient_html}
HTMLEOF

# ── Install dependencies ──────────────────────────────────────────────────────
pip3 install flask flask-cors boto3

# ── Systemd service for Flask ─────────────────────────────────────────────────
cat > /etc/systemd/system/flask-admin.service << SVCEOF
[Unit]
Description=SecureHealth Flask Admin Dashboard
After=network.target

[Service]
User=ec2-user
WorkingDirectory=/opt/admin-dashboard
Environment="DYNAMODB_TABLE=${dynamodb_table}"
Environment="S3_BUCKET=${s3_bucket}"
Environment="AWS_REGION=${aws_region}"
Environment="SNS_TOPIC_ARN=${sns_topic_arn}"
Environment="ADMIN_API_URL=$ADMIN_API_URL"
ExecStart=/usr/bin/python3 /opt/admin-dashboard/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

# ── Start Flask service ───────────────────────────────────────────────────────
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable flask-admin
systemctl start flask-admin