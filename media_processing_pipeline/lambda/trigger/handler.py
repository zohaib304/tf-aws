import json
import boto3
import os

s3_client = boto3.client("s3")

def lambda_handler(event, context):
    records = event.get("Records", [])

    bucket = event["Records"][0]["s3"]["bucket"]["name"]
    key = event["Records"][0]["s3"]["object"]["key"]

    print(f"Received event for bucket: {bucket}, key: {key}")

    input_path = f"s3://{bucket}/{key}"
    output_bucket_arn = os.environ["OUTPUT_BUCKET_ARN"]
    output_bucket_name = output_bucket_arn.split(":::")[-1]
    output_path = f"s3://{output_bucket_name}/output/{key}/"

    print(f"Input path: {input_path}")
    print(f"Output path: {output_path}")

    mediaconvert = boto3.client("mediaconvert", endpoint_url=os.environ['MEDIACONVERT_ENDPOINT'])

    job_settings = {
        "Inputs": [{
            "FileInput": input_path,
            "AudioSelectors": {"Audio Selector 1": {"DefaultSelection": "DEFAULT"}},
            "VideoSelector": {}
        }],
        "OutputGroups": [{
            "Name": "HLS Group",
            "OutputGroupSettings": {
                "Type": "HLS_GROUP_SETTINGS",
                "HlsGroupSettings": {
                    "Destination": output_path,
                    "SegmentLength": 6,
                    "MinSegmentLength": 0
                }
            },
            "Outputs": [
                # 1080p
                {
                    "NameModifier": "_1080p",
                    "VideoDescription": {
                        "CodecSettings": {"Codec": "H_264", "H264Settings": {"Bitrate": 5000000}},
                        "Height": 1080
                    },
                    "AudioDescriptions": [{"CodecSettings": {"Codec": "AAC", "AacSettings": {"Bitrate": 128000, "CodingMode": "CODING_MODE_2_0", "SampleRate": 48000}}}],
                    "ContainerSettings": {"Container": "M3U8"}
                },
                # 720p
                {
                    "NameModifier": "_720p",
                    "VideoDescription": {
                        "CodecSettings": {"Codec": "H_264", "H264Settings": {"Bitrate": 2500000}},
                        "Height": 720
                    },
                    "AudioDescriptions": [{"CodecSettings": {"Codec": "AAC", "AacSettings": {"Bitrate": 128000, "CodingMode": "CODING_MODE_2_0", "SampleRate": 48000}}}],
                    "ContainerSettings": {"Container": "M3U8"}
                },
                # 360p
                {
                    "NameModifier": "_360p",
                    "VideoDescription": {
                        "CodecSettings": {"Codec": "H_264", "H264Settings": {"Bitrate": 800000}},
                        "Height": 360
                    },
                    "AudioDescriptions": [{"CodecSettings": {"Codec": "AAC", "AacSettings": {"Bitrate": 128000, "CodingMode": "CODING_MODE_2_0", "SampleRate": 48000}}}],
                    "ContainerSettings": {"Container": "M3U8"}
                }
            ]
        }]
    }

    mediaconvert.create_job(
        Role=os.environ['MEDIACONVERT_ROLE_ARN'],
        Settings=job_settings
    )