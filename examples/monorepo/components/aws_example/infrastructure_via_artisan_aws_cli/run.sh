#!/bin/sh

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
LOCALSTACK_ENDPOINT="http://localhost:4566"

TEST_BUCKET=test-bucket

if [ "$__DESTROY__" == "1" ]; then
    aws --endpoint-url=$LOCALSTACK_ENDPOINT s3 rb --force s3://$TEST_BUCKET
else
    aws --endpoint-url=$LOCALSTACK_ENDPOINT s3api head-bucket --bucket $TEST_BUCKET &> /dev/null

    # The idempotent artisan :)
    if [ $? -eq 0 ]; then
        echo "Bucket $TEST_BUCKET already created"
    else
        aws --endpoint-url=$LOCALSTACK_ENDPOINT s3 mb s3://$TEST_BUCKET
        echo "Bucket $TEST_BUCKET created"
    fi
fi