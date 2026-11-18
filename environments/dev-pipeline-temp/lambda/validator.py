import json
from urllib.parse import unquote_plus

def lambda_handler(event, context):
    detail = event.get("detail", {})
    bucket = detail.get("bucket", {}).get("name")
    encoded_key = detail.get("object", {}).get("key")

    if not bucket or not encoded_key:
        raise ValueError("Missing S3 bucket or object key")

    key = unquote_plus(encoded_key)

    if not key.startswith("raw/"):
        raise ValueError("Only objects in the raw/ prefix are accepted")

    if not key.lower().endswith(".json"):
        raise ValueError("Only JSON input files are accepted")

    return {
        "bucket": bucket,
        "key": key,
        "status": "VALIDATED"
    }
