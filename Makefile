export AWS_ACCESS_KEY_ID ?= test
export AWS_SECRET_ACCESS_KEY ?= test
export AWS_DEFAULT_REGION=us-east-1
SHELL := /bin/bash

usage:		## Show this help
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$//' | sed -e 's/##//'

install:	## Install dependencies
	@which localstack || pip install localstack
	@which awslocal || pip install awscli-local

start:		## Start LocalStack
	@test -n "${LOCALSTACK_AUTH_TOKEN}" || (echo "LOCALSTACK_AUTH_TOKEN is not set. Find your token at https://app.localstack.cloud/workspace/auth-token"; exit 1)
	@LOCALSTACK_AUTH_TOKEN=$(LOCALSTACK_AUTH_TOKEN) localstack start -d

stop:		## Stop LocalStack
	@localstack stop

ready:		## Wait until LocalStack is ready
	@echo Waiting on the LocalStack container...
	@localstack wait -t 30 && echo LocalStack is ready to use! || (echo Gave up waiting on LocalStack, exiting. && exit 1)

logs:		## Save the logs in a separate file
	@localstack logs > logs.txt

all: backend frontend-build

TEMPLATES = auth product-mock shoppingcart-service
REGION := us-east-1
# REGION := $(shell python3 -c 'import boto3; print(boto3.Session().region_name)')
ifndef S3_BUCKET
ACCOUNT_ID := 000000000000
# ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text)
S3_BUCKET = aws-serverless-shopping-cart-src-$(ACCOUNT_ID)-$(REGION)
endif


backend: create-bucket
	$(MAKE) -C backend TEMPLATE=auth S3_BUCKET=$(S3_BUCKET) REGION=${REGION}
	$(MAKE) -C backend TEMPLATE=product-mock S3_BUCKET=$(S3_BUCKET) REGION=${REGION}
	$(MAKE) -C backend TEMPLATE=shoppingcart-service S3_BUCKET=$(S3_BUCKET) REGION=${REGION}

backend-delete:
	$(MAKE) -C backend delete TEMPLATE=auth REGION=${REGION}
	$(MAKE) -C backend delete TEMPLATE=product-mock REGION=${REGION}
	$(MAKE) -C backend delete TEMPLATE=shoppingcart-service REGION=${REGION}

backend-tests:
	$(MAKE) -C backend tests

create-bucket:
	@echo "Checking if S3 bucket exists s3://$(S3_BUCKET)"
	@awslocal s3api head-bucket --bucket $(S3_BUCKET) || (echo "bucket does not exist at s3://$(S3_BUCKET), creating it..." ; awslocal s3 mb s3://$(S3_BUCKET) --region $(REGION))

amplify-deploy:
	aws cloudformation deploy \
		--template-file ./amplify-ci/amplify-template.yaml \
		--capabilities CAPABILITY_IAM \
		--parameter-overrides \
			OauthToken=$(GITHUB_OAUTH_TOKEN) \
			Repository=$(GITHUB_REPO) \
			BranchName=$(GITHUB_BRANCH) \
			SrcS3Bucket=$(S3_BUCKET) \
		--stack-name CartApp

frontend-serve: 
	$(MAKE) -C frontend serve

frontend-build: 
	$(MAKE) -C frontend build

.PHONY: usage install start stop ready logs all backend backend-delete backend-tests create-bucket amplify-deploy frontend-serve frontend-build
