import sys
from urllib.parse import unquote_plus
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

args = getResolvedOptions(
    sys.argv,
    ["JOB_NAME", "source_bucket", "source_key", "target_bucket"]
)

sc = SparkContext()
glue_context = GlueContext(sc)
spark = glue_context.spark_session

job = Job(glue_context)
job.init(args["JOB_NAME"], args)

source_bucket = args["source_bucket"]
source_key = unquote_plus(args["source_key"])
target_bucket = args["target_bucket"]

source_path = f"s3://{source_bucket}/{source_key}"

file_name = source_key.rsplit("/", 1)[-1].rsplit(".", 1)[0]
output_path = f"s3://{target_bucket}/processed/{file_name}/"

data = spark.read.json(source_path)

if data.rdd.isEmpty():
    raise ValueError(f"No records found in {source_path}")

data.write.mode("overwrite").parquet(output_path)

print(f"Processed {source_path} into {output_path}")

job.commit()
