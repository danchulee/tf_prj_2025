.PHONY: help fmt install_phase_1 install_phase_2 install_phase_3 install_all cleanup_phase_1 cleanup_phase_2 cleanup_phase_3 cleanup_all

# Default values
ENV ?= dev
PROFILE ?= playground-admin

help:
	@echo "Available targets:"
	@echo "  make install_phase_1 ENV=dev PROFILE=playground-admin  - Install Phase 1 (Network)"
	@echo "  make install_phase_2 ENV=dev PROFILE=playground-admin  - Install Phase 2 (IAM)"
	@echo "  make install_phase_3 ENV=dev PROFILE=playground-admin  - Install Phase 3 (Computing)"
	@echo "  make install_all ENV=dev PROFILE=playground-admin      - Install all phases sequentially"
	@echo "  make cleanup_phase_1 ENV=dev PROFILE=playground-admin  - Cleanup Phase 1 (Network)"
	@echo "  make cleanup_phase_2 ENV=dev PROFILE=playground-admin  - Cleanup Phase 2 (IAM)"
	@echo "  make cleanup_phase_3 ENV=dev PROFILE=playground-admin  - Cleanup Phase 3 (Computing)"
	@echo "  make cleanup_all ENV=dev PROFILE=playground-admin      - Cleanup all phases sequentially"
	@echo "  make fmt                                                - Format all Terraform files"
	@echo ""
	@echo "Default values: ENV=dev, PROFILE=playground-admin"

fmt:
	@echo "Formatting all Terraform files..."
	@cd phase_1_network && make fmt
	@cd phase_2_iam && make fmt
	@cd phase_3_computing && make fmt
	@echo "All Terraform files formatted successfully!"

install_phase_1:
	@echo "=========================================="
	@echo "Installing Phase 1: Network (VPC, Subnets, VPC Endpoints)"
	@echo "Environment: $(ENV)"
	@echo "Profile: $(PROFILE)"
	@echo "=========================================="
	@cd phase_1_network && ENV=$(ENV) PROFILE=$(PROFILE) make init
	@cd phase_1_network && ENV=$(ENV) PROFILE=$(PROFILE) make apply
	@echo "Phase 1 installation completed!"

install_phase_2:
	@echo "=========================================="
	@echo "Installing Phase 2: IAM (Team Roles, SSM Access Control)"
	@echo "Environment: $(ENV)"
	@echo "Profile: $(PROFILE)"
	@echo "=========================================="
	@cd phase_2_iam && ENV=$(ENV) PROFILE=$(PROFILE) make init
	@cd phase_2_iam && ENV=$(ENV) PROFILE=$(PROFILE) make apply
	@echo "Phase 2 installation completed!"
	@echo ""
	@echo "Switch Role URLs:"
	@cd phase_2_iam && terraform output assume_role_commands

install_phase_3:
	@echo "=========================================="
	@echo "Installing Phase 3: Computing (EC2, ALB, Security Groups)"
	@echo "Environment: $(ENV)"
	@echo "Profile: $(PROFILE)"
	@echo "=========================================="
	@cd phase_3_computing && ENV=$(ENV) PROFILE=$(PROFILE) make init
	@cd phase_3_computing && ENV=$(ENV) PROFILE=$(PROFILE) make apply
	@echo "Phase 3 installation completed!"

install_all:
	@echo "=========================================="
	@echo "Installing All Phases"
	@echo "Environment: $(ENV)"
	@echo "Profile: $(PROFILE)"
	@echo "=========================================="
	@$(MAKE) install_phase_1 ENV=$(ENV) PROFILE=$(PROFILE)
	@$(MAKE) install_phase_2 ENV=$(ENV) PROFILE=$(PROFILE)
	@$(MAKE) install_phase_3 ENV=$(ENV) PROFILE=$(PROFILE)
	@echo ""
	@echo "=========================================="
	@echo "All phases installed successfully!"
	@echo "=========================================="

cleanup_phase_3:
	@echo "=========================================="
	@echo "Cleaning up Phase 3: Computing"
	@echo "Environment: $(ENV)"
	@echo "Profile: $(PROFILE)"
	@echo "=========================================="
	@cd phase_3_computing && ENV=$(ENV) PROFILE=$(PROFILE) make destroy
	@echo "Phase 3 cleaned up!"

cleanup_phase_2:
	@echo "=========================================="
	@echo "Cleaning up Phase 2: IAM"
	@echo "Environment: $(ENV)"
	@echo "Profile: $(PROFILE)"
	@echo "=========================================="
	@cd phase_2_iam && ENV=$(ENV) PROFILE=$(PROFILE) make destroy
	@echo "Phase 2 cleaned up!"

cleanup_phase_1:
	@echo "=========================================="
	@echo "Cleaning up Phase 1: Network"
	@echo "Environment: $(ENV)"
	@echo "Profile: $(PROFILE)"
	@echo "=========================================="
	@cd phase_1_network && ENV=$(ENV) PROFILE=$(PROFILE) make destroy
	@echo "Phase 1 cleaned up!"

cleanup_all:
	@echo "=========================================="
	@echo "Cleaning up All Phases (Reverse Order)"
	@echo "Environment: $(ENV)"
	@echo "Profile: $(PROFILE)"
	@echo "=========================================="
	@$(MAKE) cleanup_phase_3 ENV=$(ENV) PROFILE=$(PROFILE)
	@$(MAKE) cleanup_phase_2 ENV=$(ENV) PROFILE=$(PROFILE)
	@$(MAKE) cleanup_phase_1 ENV=$(ENV) PROFILE=$(PROFILE)
	@echo ""
	@echo "=========================================="
	@echo "All phases cleaned up successfully!"
	@echo "=========================================="
