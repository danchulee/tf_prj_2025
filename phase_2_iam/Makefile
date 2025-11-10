fmt:
	@echo "Formatting Terraform files..."
	terraform fmt -recursive
	@echo "Validating Terraform files..."
	terraform validate


init:
	@echo "Initializing Terraform..."
	TF_VAR_environment=$(ENV) TF_VAR_profile=$(PROFILE) terraform init

plan:
	@echo "Planning Terraform..."
	TF_VAR_environment=$(ENV) TF_VAR_profile=$(PROFILE) terraform plan

apply:
	@echo "Applying Terraform..."
	TF_VAR_environment=$(ENV) TF_VAR_profile=$(PROFILE) terraform apply

destroy:
	@echo "Destroying Terraform resources..."
	TF_VAR_environment=$(ENV) TF_VAR_profile=$(PROFILE) terraform destroy