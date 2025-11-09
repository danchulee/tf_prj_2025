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