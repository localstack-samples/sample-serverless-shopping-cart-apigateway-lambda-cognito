# Serverless Shopping Cart with API Gateway, Lambda, Cognito, SQS, DynamoDB, and Amplify SDK

| Key          | Value                                                                                 |
| ------------ | ------------------------------------------------------------------------------------- |
| Environment  | <img src="https://img.shields.io/badge/LocalStack-deploys-4D29B4.svg?logo=data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAKgAAACoABZrFArwAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAALbSURBVHic7ZpNaxNRFIafczNTGIq0G2M7pXWRlRv3Lusf8AMFEQT3guDWhX9BcC/uFAr1B4igLgSF4EYDtsuQ3M5GYrTaj3Tmui2SpMnM3PlK3m1uzjnPw8xw50MoaNrttl+r1e4CNRv1jTG/+v3+c8dG8TSilHoAPLZVX0RYWlraUbYaJI2IuLZ7KKUWCisgq8wF5D1A3rF+EQyCYPHo6Ghh3BrP8wb1en3f9izDYlVAp9O5EkXRB8dxxl7QBoNBpLW+7fv+a5vzDIvVU0BELhpjJrmaK2NMw+YsIxunUaTZbLrdbveZ1vpmGvWyTOJToNlsuqurq1vAdWPMeSDzwzhJEh0Bp+FTmifzxBZQBXiIKaAq8BBDQJXgYUoBVYOHKQRUER4mFFBVeJhAQJXh4QwBVYeHMQJmAR5GCJgVeBgiYJbg4T8BswYPp+4GW63WwvLy8hZwLcd5TudvBj3+OFBIeA4PD596nvc1iiIrD21qtdr+ysrKR8cY42itCwUP0Gg0+sC27T5qb2/vMunB/0ipTmZxfN//orW+BCwmrGV6vd63BP9P2j9WxGbxbrd7B3g14fLfwFsROUlzBmNM33XdR6Meuxfp5eg54IYxJvXCx8fHL4F3w36blTdDI4/0WREwMnMBeQ+Qd+YC8h4g78wF5D1A3rEqwBiT6q4ubpRSI+ewuhP0PO/NwcHBExHJZZ8PICI/e73ep7z6zzNPwWP1djhuOp3OfRG5kLROFEXv19fXP49bU6TbYQDa7XZDRF6kUUtEtoFb49YUbh/gOM7YbwqnyG4URQ/PWlQ4ASllNwzDzY2NDX3WwioKmBgeqidgKnioloCp4aE6AmLBQzUExIaH8gtIBA/lFrCTFB7KK2AnDMOrSeGhnAJSg4fyCUgVHsolIHV4KI8AK/BQDgHW4KH4AqzCQwEfiIRheKKUAvjuuu7m2tpakPdMmcYYI1rre0EQ1LPo9w82qyNziMdZ3AAAAABJRU5ErkJggg==">                     |
| Services     | API Gateway, Cognito, Lambda, DynamoDB, SQS                    |
| Integrations | Serverless Application Model, CloudFormation, Amplify                                                    |
| Categories   | Serverless; Application Development                            |
| Level        | Intermediate                                                                          |
| GitHub       | [Repository link](https://github.com/aws-samples/aws-serverless-shopping-cart) |

## Introduction

The Serverless Shopping Cart with API Gateway, Lambda, Cognito, SQS, DynamoDB, and Amplify SDK demonstrates how to implement a shopping cart microservice with an integrated frontend built using Vue.js. The application sample displays a mock products page that enables users to add items to the cart without authentication, which is persisted across browser restarts. After logging in, the products are shifted to the user's cart and are removed if logging out. The products in an anonymous cart are terminated after some time, while an authenticated user's cart is persisted. Users can deploy this application sample on AWS & LocalStack using Serverless Application Model (SAM), CloudFormation, and Amplify SDK with minimal changes. To test this application sample, we will demonstrate how you use LocalStack to deploy the infrastructure on your developer machine and your CI environment.

## Architecture diagram


| Endpoint                   | Method | Description                                                                                                                     |
| -------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------- |
| `/cart`                    | `GET`  | Retrieve the shopping cart for a user, whether anonymous or logged in.                                                          |
| `/cart`                    | `POST` | Accepts a JSON payload containing product ID and quantity. Adds the specified quantity of an item to the cart.                  |
| `/cart/migrate`            | `POST` | This endpoint is called after logging in to migrate items from an anonymous user's cart to the logged-in user's cart.           |
| `/cart/checkout`           | `POST` | Empty the shopping cart.                                                                                                        |
| `/cart/{product-id}`       | `PUT`  | Accepts a JSON payload containing product ID and quantity. Updates the quantity of the specified item in the cart.              |
| `/cart/{product-id}/total` | `GET`  | Retrieve the total amount of a given product across all carts. This API is not used by the frontend but can be manually tested. |
| `/product`                 | `GET`  | Retrieve details for all products.                                                                                              |
| `/product/{product_id}`    | `GET`  | Retrieve details for a single product.                                                                                          |

## Instructions

- LocalStack Pro with the [`localstack` CLI](https://docs.localstack.cloud/getting-started/installation/#localstack-cli).
- [Serverless Application Model](https://docs.localstack.cloud/user-guide/integrations/aws-sam/) with the [`samlocal`](https://github.com/localstack/aws-sam-cli-local) installed.
- [AWS CLI](https://docs.localstack.cloud/user-guide/integrations/aws-cli/) with the [`awslocal` wrapper](https://docs.localstack.cloud/user-guide/integrations/aws-cli/#localstack-aws-cli-awslocal).
- [Node.js](https://nodejs.org/en/download/) with [`yarn`](https://yarnpkg.com/getting-started/install) installed.
- [Python 3.8.0](https://www.python.org/downloads/release/python-380/) in the `PATH`

Start LocalStack Pro with the `LOCALSTACK_API_KEY` pre-configured:

```shell
export LOCALSTACK_API_KEY=<your-api-key>
DISABLE_CUSTOM_CORS_APIGATEWAY=1 EXTRA_CORS_ALLOWED_ORIGINS=http://localhost:8080 DEBUG=1 localstack start
```

The `DISABLE_CUSTOM_CORS_APIGATEWAY` configuration variable disables CORS override by API Gateway. The `EXTRA_CORS_ALLOWED_ORIGINS` configuration variable allows our website to send requests to the container APIs. We specified `DEBUG=1` to get the printed LocalStack logs directly in the terminal (it helps later, when we need to get the Cognito confirmation code). If you prefer running LocalStack in detached mode, you can add the `-d` flag to the `localstack start` command, and use Docker Desktop to view the logs.

## Instructions

### Deploying the application

To build and deploy the resources, run the following command:

```shell
make backend
```

The above command will create an S3 bucket, deploys CloudFormation stacks for authentication, and set up a mock product and shopping cart services. Alternatively, if you wish to use a custom S3 bucket, set the `S3_BUCKET` environment variable to the name of your bucket.

The CloudFormation events from the stack operations will take a few seconds to complete. You can view the status of the stack operations in the terminal or the [CloudFormation resource browser](https://app.localstack.cloud/resources/cloudformation/stacks). On completion, the terminal will display the following message:

```shell
CloudFormation outputs from deployed stack
------------------------------------------------------------------------------------------------------------------------------------------------
Outputs                                                                                                                                                           
------------------------------------------------------------------------------------------------------------------------------------------------
Key                 CartApi                                                                                                                                       
Description         API Gateway endpoint URL for Prod stage for Cart Service                                                                                      
Value               https://0fi59sk3kb.execute-api.localhost.localstack.cloud:4566/Prod                                                                           
------------------------------------------------------------------------------------------------------------------------------------------------

Successfully created/updated stack - aws-serverless-shopping-cart-shoppingcart-service in us-east-1
```

> If the SAM application build fails, you can check if you have the Python 3.8 installed and in the `PATH`. Alternatively, use [`pyenv`](https://github.com/pyenv/pyenv) to switch between multiple versions of Python.

### Setting up the front-end

To set up the front-end, run the following command:

```shell
make frontend-serve 
```

The above command will install the dependencies, run a Node.js script to retrieve backend configuration from the SSM parameter and store to a .env.local` file. The application is then served locally at `http://localhost:8080`.

> CORS headers on the backend service default to allowing `http://localhost:8080/`. You will see CORS errors if 
you access the frontend using the IP (`http://127.0.0.1:8080/`) or a port other than `8080`.

### Testing the application

TODO

### GitHub Action

This application sample hosts an example GitHub Action workflow that starts up LocalStack, deploys the infrastructure, and checks the created resources using `awslocal`. You can find the workflow in the `.github/workflows/main.yml` file. To run the workflow, you can fork this repository and push a commit to the `main` branch.

Users can adapt this example workflow to run in their own CI environment. LocalStack supports various CI environments, including GitHub Actions, CircleCI, Jenkins, Travis CI, and more. You can find more information about the CI integration in the [LocalStack documentation](https://docs.localstack.cloud/user-guide/ci/).

## Learn more

The sample application is based on a [public AWS sample app](https://github.com/aws-samples/aws-serverless-shopping-cart) that deploys a shopping cart microservice using serverless technologies on AWS.
