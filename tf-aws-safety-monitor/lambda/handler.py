import json
import os
import boto3
import logging
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS service clients
rekognition = boto3.client("rekognition")
dynamodb    = boto3.resource("dynamodb")
sns         = boto3.client("sns")
s3          = boto3.client("s3")

# Read config from Lambda environment variables
# (set by Terraform in the environment{} block)
TABLE_NAME        = os.environ["DYNAMODB_TABLE"]
SNS_TOPIC_ARN     = os.environ["SNS_TOPIC_ARN"]
VIOLATIONS_BUCKET = os.environ["VIOLATIONS_BUCKET"]
CONFIDENCE_MIN    = float(os.environ.get("CONFIDENCE_MIN", 80))

# PPE types Rekognition can detect
REQUIRED_PPE = {
    "FACE_COVER": "Face Mask",
    "HAND_COVER": "Gloves",
    "HEAD_COVER": "Helmet / Hard Hat",
}


def lambda_handler(event, context):
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key    = record['s3']['object']['key']
        logger.info(f'Processing: s3://{bucket}/{key}')
        try:
            result = analyze_image(bucket, key)
            log_result(key, result)
            if result['violation']:
                copy_to_violations(bucket, key)
                send_alert(key, result)
        except Exception as e:
            logger.error(f'Error: {str(e)}')
            raise
    return {'statusCode': 200}

def analyze_image(bucket, key):
    ppe_findings   = run_ppe_detection(bucket, key)
    label_findings = run_label_detection(bucket, key)
    detected = list(set(ppe_findings['detected'] + label_findings['detected']))
    missing  = ppe_findings['missing']
    violation = len(missing) > 0 or not label_findings['has_safety_gear']
    return {
        'image_key':      key,
        'timestamp':      datetime.now(timezone.utc).isoformat(),
        'violation':      violation,
        'detected_ppe':   detected,
        'missing_ppe':    missing,
        'safety_labels':  label_findings['detected'],
        'summary':        build_summary(violation, detected, missing)
    }


def run_ppe_detection(bucket, key):
    detected, missing = [], []
    try:
        response = rekognition.detect_protective_equipment(
            Image={'S3Object': {'Bucket': bucket, 'Name': key}},
            SummarizationAttributes={
                'MinConfidence': CONFIDENCE_MIN,
                'RequiredEquipmentTypes': list(REQUIRED_PPE.keys())
            }
        )
        summary = response.get('Summary', {})
        for p in summary.get('PersonsWithRequiredEquipment', []):
            detected.append(f'Person {p} fully equipped')
        for p in summary.get('PersonsWithoutRequiredEquipment', []):
            missing.append(f'Person {p} missing PPE')
    except Exception as e:
        logger.warning(f'PPE detection error: {e}')
    return {'detected': detected, 'missing': missing}

SAFETY_KEYWORDS = ['Helmet','Hard Hat','Safety Vest','High Visibility','Hardhat']

def run_label_detection(bucket, key):
    detected, has_safety_gear = [], False
    response = rekognition.detect_labels(
        Image={'S3Object': {'Bucket': bucket, 'Name': key}},
        MaxLabels=30, MinConfidence=CONFIDENCE_MIN
    )
    for label in response.get('Labels', []):
        for kw in SAFETY_KEYWORDS:
            if kw.lower() in label['Name'].lower():
                detected.append(f"{label['Name']} ({label['Confidence']:.1f}%)")
                has_safety_gear = True
    return {'detected': detected, 'has_safety_gear': has_safety_gear}


def log_result(image_key, result):
    table = dynamodb.Table(TABLE_NAME)
    table.put_item(Item={
        'image_key':  image_key,
        'timestamp':  result['timestamp'],
        'violation':  result['violation'],
        'detected_ppe': result['detected_ppe'],
        'missing_ppe':  result['missing_ppe'],
        'summary':    result['summary']
    })

def copy_to_violations(source_bucket, key):
    dest = f"violations/{datetime.now(timezone.utc).strftime('%Y/%m/%d')}/{key}"
    s3.copy_object(
        CopySource={'Bucket': source_bucket, 'Key': key},
        Bucket=VIOLATIONS_BUCKET, Key=dest
    )

def send_alert(image_key, result):
    message = f'''
WORKPLACE SAFETY VIOLATION DETECTED
Image   : {image_key}
Time    : {result['timestamp']}
Summary : {result['summary']}
Missing : {', '.join(result['missing_ppe']) or 'PPE not detected'}
'''
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=f'Safety Violation - {image_key}',
        Message=message
    )

def build_summary(violation, detected, missing):
    if not violation:
        return f'COMPLIANT - PPE detected: {", ".join(detected)}'
    return f'VIOLATION - Missing: {", ".join(missing) or "No PPE detected"}'
