BBLU		=	\033[1;34m
BGREEN		=	\033[1;32m
BRED		=	\033[1;31m
BLU			=	\033[0;34m
GRN			=	\033[0;32m
RED			=	\033[0;31m
RST			=	\033[0m
NAMESPACES ?= dev argocd
NAME		=	p3

USERNAME := $(shell whoami)


all: print_header up

print_header:
	@echo "$(BBLU)===================================================="
	@echo "$(BBLU)"
	@echo "$(BBLU)\033[17G██╗░█████╗░████████╗"
	@echo "$(BBLU)\033[17G██║██╔══██╗╚══██╔══╝"
	@echo "$(BBLU)\033[17G██║██║░░██║░░░██║░░░"
	@echo "$(BBLU)\033[17G██║██║░░██║░░░██║░░░"
	@echo "$(BBLU)\033[17G██║╚█████╔╝░░░██║░░░"
	@echo "$(BBLU)\033[17G╚═╝░╚════╝░░░░╚═╝░░░"
	@echo "$(BBLU)"
	@echo "$(BBLU)=======================> p3 <======================="
	@echo "$(RST)"

up:
	@echo "${YELLOW}Running scripts on Linux ...${END}"
	@sudo ./scripts/setup.sh && ./scripts/launch_k3d.sh && ./scripts/argocd.sh


clean:
	@echo "$(GRN)[CLEAN]  :$(RST) Deleting pods and namespaces: $(NAMESPACES)...$(BGREEN)\033[47G[✔]$(RST)"
	@for ns in $(NAMESPACES); do \
		if sudo kubectl get namespace $$ns >/dev/null 2>&1; then \
			echo "-> Deleting pods in namespace $$ns"; \
			sudo kubectl delete pods --all -n $$ns --ignore-not-found || true; \
			echo "-> Deleting namespace $$ns"; \
			sudo kubectl delete namespace $$ns --wait --ignore-not-found || true; \
		else \
			echo "-> namespace $$ns not found, skipping"; \
		fi; \
	done

re: fclean all

fclean: clean
	@sudo k3d cluster delete $(USERNAME)
	echo "$(GRN)[CLEAN]  :$(RST) Cleaning project and delete cluster...$(BGREEN)\033[47G[✔]$(RST)"

.SILENT:

.PHONY: all print_header up clean fclean