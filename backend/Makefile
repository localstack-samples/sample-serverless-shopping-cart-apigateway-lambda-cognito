all: build deploy

nolayers: build deploy

STACKNAME = aws-serverless-shopping-cart-$(TEMPLATE)

build:
	sam build -t $(TEMPLATE).yaml

build_layers:
	$(MAKE) -C ./layers

deploy:  # s3 bucket still needed for layer
	sam deploy --capabilities CAPABILITY_NAMED_IAM --stack-name $(STACKNAME) --s3-bucket $(S3_BUCKET)

tests:
	py.test -v

delete:
	aws cloudformation delete-stack --stack-name $(STACKNAME)
	@echo "Waiting for stack $(STACKNAME) to be deleted..."
	@aws cloudformation wait stack-delete-complete --stack-name $(STACKNAME)

.PHONY: build build_layers package deploy nolayers delete