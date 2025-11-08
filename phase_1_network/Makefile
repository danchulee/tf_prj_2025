project-init:
	@echo "Installing dependencies..."
	brew install localstack/tap/localstack-cli;
	pip install terraform-local;
	localstack start -d;

fmt:
	@echo "Validating Terraform files..."
	terraform validate;
	terraform fmt --recursive --check;


init:
	@echo "Initializing Terraform..."
ifeq ($(ENV),local)
	TF_VAR_environment=local tflocal init;
else
	TF_VAR_environment=$(ENV) terraform init;
endif

plan:
	@echo "Planning Terraform..."
ifeq ($(ENV),local)
	TF_VAR_environment=local tflocal plan;
else
	TF_VAR_environment=$(ENV) terraform plan;
endif

apply:
	@echo "Applying Terraform..."
ifeq ($(ENV),local)
	TF_VAR_environment=local tflocal apply;
else
	TF_VAR_environment=$(ENV) terraform apply;
endif

local-status:
	@echo "Checking LocalStack status..."
	localstack status services