all: build deploy
ORIGIN ?= http://localhost:8080
STACKNAME ?= aws-serverless-shopping-cart

build:
	@echo "Building template $(TEMPLATE).yaml..."
	@samlocal build -u -t $(TEMPLATE).yaml --region $(REGION)

deploy:  # s3 bucket still needed for layer
	@echo "Deploying stack $(STACKNAME)-$(TEMPLATE)..."
	@samlocal deploy --capabilities CAPABILITY_NAMED_IAM --stack-name $(STACKNAME)-$(TEMPLATE) --s3-bucket $(S3_BUCKET) --parameter-overrides AllowedOrigin=$(ORIGIN) --no-fail-on-empty-changeset --region $(REGION)

tests:
	py.test -v

delete:
	@awslocal cloudformation delete-stack --stack-name $(STACKNAME)-$(TEMPLATE) --region $(REGION)
	@echo "Waiting for stack $(STACKNAME)-$(TEMPLATE) to be deleted..."
	@awslocal cloudformation wait stack-delete-complete --stack-name $(STACKNAME)-$(TEMPLATE) --region $(REGION)

.PHONY: build package deploy delete
