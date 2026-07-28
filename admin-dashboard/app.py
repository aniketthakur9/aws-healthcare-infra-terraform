from flask import Flask, render_template, request, redirect, jsonify
from flask_cors import CORS
import boto3
import uuid
import json
import os
from datetime import datetime

app = Flask(__name__)
CORS(app)

# ── Config ─────────────────────────────────────────
TABLE   = os.environ.get('DYNAMODB_TABLE', 'Secure-Health-patients')
BUCKET  = os.environ.get('S3_BUCKET', '')
REGION  = os.environ.get('AWS_REGION', 'us-east-2')
SNS_ARN = os.environ.get('SNS_TOPIC_ARN', '')

# ── AWS Clients ────────────────────────────────────
dynamodb   = boto3.resource('dynamodb', region_name=REGION)
s3         = boto3.client('s3', region_name=REGION)
cloudwatch = boto3.client('cloudwatch', region_name=REGION)
sns        = boto3.client('sns', region_name=REGION)

def get_table():
    return dynamodb.Table(TABLE)

# ── SNS Notification Helper ────────────────────────
def send_sns(subject, message):
    """Send an SNS notification for any important action."""
    if not SNS_ARN:
        print(f'[SNS] No ARN configured — skipping: {subject}')
        return
    try:
        sns.publish(
            TopicArn=SNS_ARN,
            Subject=subject,
            Message=message
        )
        print(f'[SNS] Sent: {subject}')
    except Exception as e:
        print(f'[ERROR] SNS publish failed: {e}')

# ── CloudWatch Metric Helper ───────────────────────
def push_metric(metric_name, dimensions=None, value=1):
    try:
        metric = {
            'MetricName': metric_name,
            'Value': value,
            'Unit': 'Count',
        }
        if dimensions:
            metric['Dimensions'] = dimensions
        cloudwatch.put_metric_data(
            Namespace='SecureHealth/Patients',
            MetricData=[metric]
        )
        print(f'[CW] Metric pushed: {metric_name}')
    except Exception as e:
        print(f'[ERROR] CloudWatch metric failed: {e}')

# ── UI Routes ──────────────────────────────────────

@app.route('/')
def index():
    patients = get_table().scan().get('Items', [])
    patients.sort(key=lambda x: x.get('admitted_on', ''), reverse=True)
    return render_template('index.html', patients=patients)

@app.route('/add', methods=['GET', 'POST'])
def add_patient():
    if request.method == 'POST':
        data = request.form.to_dict()
        _save_patient(data)
        return redirect('/')
    return render_template('add_patient.html')

# ── API: List all patients ─────────────────────────

@app.route('/api/patients', methods=['GET'])
def api_patients():
    patients = get_table().scan().get('Items', [])
    patients.sort(key=lambda x: x.get('admitted_on', ''), reverse=True)
    return jsonify(patients)

# ── API: Add patient ───────────────────────────────

@app.route('/api/add_patient', methods=['POST'])
def api_add_patient():
    data = request.get_json(force=True)
    patient_id = _save_patient(data)
    return jsonify({'ok': True, 'patient_id': patient_id}), 201

# ── API: Delete patient ────────────────────────────

@app.route('/api/delete_patient', methods=['DELETE'])
def api_delete_patient():
    data = request.get_json(force=True)
    patient_id = data.get('patient_id', '').strip()
    reason     = data.get('reason', 'No reason provided').strip()

    if not patient_id:
        return jsonify({'error': 'patient_id required'}), 400

    table  = get_table()
    record = table.get_item(Key={'patient_id': patient_id}).get('Item')

    if not record:
        return jsonify({'error': 'Not found'}), 404

    # ── Backup to S3 before deleting ──────────────
    audit_record = {
        **record,
        'deleted_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'deletion_reason': reason
    }
    if BUCKET:
        try:
            s3.put_object(
                Bucket=BUCKET,
                Key=f'deletions/{patient_id}_{datetime.now().strftime("%Y%m%d%H%M%S")}.json',
                Body=json.dumps(audit_record),
                ContentType='application/json'
            )
            print(f'[S3] Deletion backup saved for {patient_id}')
        except Exception as e:
            print(f'[ERROR] S3 backup failed: {e}')

    # ── Delete from DynamoDB ───────────────────────
    table.delete_item(Key={'patient_id': patient_id})

    # ── CloudWatch metric ──────────────────────────
    push_metric('PatientDeleted')

    # ── SNS notification for deletion ─────────────
    send_sns(
        subject='🗑 Patient Record Deleted — SecureHealth',
        message=(
            f"A patient record has been deleted.\n\n"
            f"Patient ID : {patient_id}\n"
            f"Name       : {record.get('name', 'N/A')}\n"
            f"Diagnosis  : {record.get('diagnosis', 'N/A')}\n"
            f"Deleted At : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
            f"Reason     : {reason}\n\n"
            f"Audit backup saved to S3 under deletions/{patient_id}.json"
        )
    )

    print(f'[-] Deleted {patient_id}')
    return jsonify({'ok': True})

# ── API: Accept invitation ─────────────────────────
# Doctors/nurses call this when they accept their invite to join the system

@app.route('/api/accept_invitation', methods=['POST'])
def api_accept_invitation():
    data  = request.get_json(force=True)
    name  = data.get('name', 'Unknown')
    role  = data.get('role', 'Staff')     # Doctor / Nurse
    email = data.get('email', 'N/A')

    # ── CloudWatch metric ──────────────────────────
    push_metric('InvitationAccepted', dimensions=[{'Name': 'Role', 'Value': role}])

    # ── SNS notification ───────────────────────────
    send_sns(
        subject=f'✅ Invitation Accepted — {role} joined SecureHealth',
        message=(
            f"A new staff member has accepted their invitation.\n\n"
            f"Name  : {name}\n"
            f"Role  : {role}\n"
            f"Email : {email}\n"
            f"Time  : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
        )
    )

    print(f'[✅] Invitation accepted: {name} ({role})')
    return jsonify({'ok': True, 'message': f'Welcome, {name}!'})

# ── Core Save Logic ────────────────────────────────

def _save_patient(data):
    patient_id  = 'P' + str(uuid.uuid4())[:8].upper()
    admitted_on = datetime.now().strftime('%Y-%m-%d %H:%M')
    status      = data.get('status', 'Stable')

    # ── Save ALL fields that frontend sends ────────
    record = {
        'patient_id':  patient_id,
        'name':        data.get('name', ''),
        'age':         str(data.get('age', '')),
        'gender':      data.get('gender', ''),
        'blood_group': data.get('blood_group', ''),
        'phone':       data.get('phone', ''),
        'diagnosis':   data.get('diagnosis', ''),
        'doctor':      data.get('doctor', ''),
        'symptoms':    data.get('symptoms', ''),
        'medication':  data.get('medication', ''),
        'status':      status,
        'admitted_on': admitted_on,
    }

    # ── Save to DynamoDB ───────────────────────────
    get_table().put_item(Item=record)

    # ── Backup to S3 ──────────────────────────────
    if BUCKET:
        try:
            s3.put_object(
                Bucket=BUCKET,
                Key=f'patients/{patient_id}.json',
                Body=json.dumps(record),
                ContentType='application/json'
            )
        except Exception as e:
            print(f'[ERROR] S3 backup failed: {e}')

    # ── CloudWatch metric ──────────────────────────
    push_metric('PatientAdmitted', dimensions=[{'Name': 'Status', 'Value': status}])

    # ── SNS notification for every new patient ─────
    subject = (
        '🚨 CRITICAL Patient Admitted — Immediate Attention Required'
        if status == 'Critical'
        else f'🏥 New Patient Admitted — SecureHealth'
    )
    send_sns(
        subject=subject,
        message=(
            f"A new patient has been admitted to the system.\n\n"
            f"Patient ID : {patient_id}\n"
            f"Name       : {record['name']}\n"
            f"Age        : {record['age']}\n"
            f"Diagnosis  : {record['diagnosis']}\n"
            f"Doctor     : {record['doctor']}\n"
            f"Status     : {status}\n"
            f"Admitted   : {admitted_on}\n\n"
            f"{'⚠️ CRITICAL STATUS — Please respond immediately!' if status == 'Critical' else 'Record saved to encrypted DynamoDB + S3.'}"
        )
    )

    print(f'[+] Saved {patient_id} ({status})')
    return patient_id

# ── Run App ────────────────────────────────────────

if __name__ == '__main__':
    print("🚀 SecureHealth Flask running on port 5000")
    app.run(host='0.0.0.0', port=5000, debug=False)