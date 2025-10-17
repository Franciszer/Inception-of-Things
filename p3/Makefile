BBLU		=	\033[1;34m
BGREEN		=	\033[1;32m
BRED		=	\033[1;31m
BLU			=	\033[0;34m
GRN			=	\033[0;32m
RED			=	\033[0;31m
RST			=	\033[0m

NAME		=	p3

USERNAME := $(shell whoami)


all: print_header up clean

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
	@sudo ./scripts/setup.sh

clean:
# 	${RM} ./confs/kubectl
# 	${RM} ./confs/kubectl.sha256 
# 	echo "$(RED)[CLEAN]  :$(RST) Cleaning project...$(BGREEN)\033[47G[✔]$(RST)"

fclean:
	${RM} ./confs/kubectl
	${RM} ./confs/kubectl.sha256
	@sudo k3d cluster delete $(USERNAME)
	echo "$(RED)[CLEAN]  :$(RST) Cleaning project and delete cluster...$(BGREEN)\033[47G[✔]$(RST)"

.SILENT:

.PHONY: all print_header up clean fclean