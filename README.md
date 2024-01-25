# django-ecs-boilerplate
This is boilerplate code for standing up a vanilla Django app and deploying it to ECS.

* We use Terraform to deploy everything.  It just creates one stack, but could be extended to include separate stacks for dev/stage/prod, etc
* Terraform will set up all the necessary infrastructure to run this bad boy in a pretty scalable way.  You get a VPC with public and private subnets, an ALB that talks to ECS, an RDS instance (Postgres), Cloudwatch application logging, etc.  Most of the stuff that needs to be edited is in `terraform/variables.tf`.
* The ECS cluster itself uses EC2 instances.  It could be modified to use Fargate but right now, EC2 instances get the job done.
* Django itself is deployed using a combinagion of NGINX and Gunicorn.  We deploy an NGINX container that forwards requests from the ALB to the Django container.
* The Django install itself is pretty vanilla.  We use `whitenoise` to serve static files and have the `jazzmin` admin theme installed, basically because its pretty. Migrations get run from an ephemeral container whenever you deploy.
* Make sure to clean up the settings files before going to production (`ALLOWED_HOSTS`, `SECRET_KEY`, etc).

## Getting Started
Before you start:

1) You need Docker running locally.  Builds will work on an M1 macbook, so you're good there.
2) Create two ECR repositories in the AWS console, one for the nginx container and one for the Django container.  Mine are called `nginx` and `canary` (the name of my vanilla django app).
3) Get your AWS creds setup the usual way in ~/.aws/credentials and make sure the awscli is installed.
4) Install the `terraform` CLI.
5) If you want a clean domain, make sure it has a valid cert.  We'll setup the CNAME later.

Clone this repo locally and setup a virtual env in the root directory:
   
```
$ python -m venv ./env
$ source ./env/bin/activate
$ pip install -r requirements.txt
```

Setup a local .env file:

```
$ touch .env
```
Open the .env file and add your aws profile and region of choice:
```
AWS_PROFILE=<your profile name>
AWS_DEFAULT_REGION=<your aws region>
```

### Build the Containers
We're going to build the docker containers and push them to ECR.

First, get the login creds:
```
$ aws ecr get-login-password --region us-east-1  --profile <AWS_PROFILE> | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
```

Now the NGINX container (from root directory):
```
$ cd services/nginx
$ docker build -t <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/nginx .
$ docker push <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/nginx:latest
```

Now the Django container (again, from root directory):
```
$ cd services/canary
$ docker build -t <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/canary .
$ docker push <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/canary:latest
```

### Deploy the Infrastructure

First, open up `terraform/variables.tf` and change anything you want to change.  At minimum, you need to swap the ECR repos and the SSL cert.

Then, deploy the stack (from root):

```
$ cd terraform
$ terraform init
$ terraform apply
```

Terraform is now going to go create your stack.  Its gonna take a little while the first time. Once its done you should get the alb domain as n output, something like this:
```
stage-alb-1297053109.us-east-1.elb.amazonaws.com
```

### Setup the domain
In the AWS console, navigate to Route53 and add a cname record from your domain/sub-domain to the ALB. 

## Done

That's it.  You should be able to navigate to your domain and see Django working.

One thing to note: there isn't a great way to create super users.  I usually do this by creating another ephemeral django container that runs the `createsuperuser` management command with the username and password as env vars in the container.  I code it in, deploy it once, then delete the container from config.  This is done in `08_ecs.tf`.

If you change the infrastructure, just re-run `terraform apply`.  If you change the application code, just rebuild and push the relative containers then run the `scripts/update-ecs.py`.

## Future Improvements
* move the RDS password (and other secrets) into AWS Secret Manager
* make it easier to deploy multiple environments (dev, stage, prod, etc), separate out Django settings per environment
* add `celery` support
* move terraform state to s3
