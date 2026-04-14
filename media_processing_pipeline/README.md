# Media Processing Pipeline (Terraform + AWS)

This project provisions an AWS-based video processing pipeline using Terraform.

When a video is uploaded to the upload S3 bucket, an S3 event invokes a Lambda function. The Lambda function submits an AWS Elemental MediaConvert job that creates HLS outputs in multiple resolutions and writes results to an output S3 bucket.

## Architecture

1. Upload a video to the upload bucket.
2. S3 ObjectCreated event invokes Lambda.
3. Lambda submits a MediaConvert job.
4. MediaConvert reads input from upload bucket and writes HLS outputs to output bucket.

## What Terraform Creates

- Two S3 buckets via reusable module:
  - Upload bucket with CORS and S3 event notification enabled
  - Output bucket with versioning and optional lifecycle policy
- Lambda function and execution role via reusable module
- Lambda invoke permission for S3
- IAM policies:
  - Lambda read access to uploaded objects
  - Lambda permission to create MediaConvert jobs
  - MediaConvert role with read/write S3 access

## Project Structure

- `main.tf`: Root infrastructure wiring and IAM policies
- `variables.tf`: Root input variables
- `outputs.tf`: Root outputs
- `terraform.tf`: Terraform and provider requirements
- `lambda/trigger/handler.py`: Lambda code that submits MediaConvert jobs
- `modules/s3/*`: Reusable S3 bucket module
- `modules/lambda/*`: Reusable Lambda module

## Prerequisites

- Terraform >= 1.2
- AWS account with permission to create:
  - S3 buckets
  - Lambda functions and IAM roles/policies
  - MediaConvert jobs/roles
- AWS credentials configured locally (for example via AWS CLI profile or environment variables)

## Required Input Variable

Set the account-specific MediaConvert endpoint URL.

Example in `terraform.tfvars`:

```hcl
mediaconvert_endpoint_url = "https://abcd1234.mediaconvert.us-east-1.amazonaws.com"
```

You can get the endpoint with AWS CLI:

```bash
aws mediaconvert describe-endpoints --region us-east-1
```

## Deploy

```bash
terraform init
terraform plan
terraform apply
```

## Usage

1. Upload a video file to the upload bucket created by Terraform.
2. Lambda triggers automatically and submits a MediaConvert job.
3. Check MediaConvert job status in AWS Console.
4. HLS outputs are written under:
   - `s3://<output-bucket>/output/<original-key>/`

## Notes

- Region is currently set to `us-east-1` in `main.tf`.
- Bucket names are currently hard-coded in root `main.tf`:
  - `video-upload-bucket-9613`
  - `video-output-bucket-9613`
  Update these names if they are not globally unique in your AWS account.
- Lambda runtime in module defaults to `python3.12`.

## Destroy

To remove all resources:

```bash
terraform destroy
```

## Troubleshooting

- If Lambda is invoked but no outputs are generated:
  - Verify `mediaconvert_endpoint_url` is correct.
  - Confirm Lambda execution role has MediaConvert permissions.
  - Confirm MediaConvert role has S3 read/write access for both buckets.
- If `terraform apply` fails with bucket name conflicts:
  - Change bucket names in `main.tf` to globally unique names.
