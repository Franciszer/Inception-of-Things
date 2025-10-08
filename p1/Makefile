BBLU		=	\033[1;34m
BGREEN		=	\033[1;32m
BRED		=	\033[1;31m
BLU			=	\033[0;34m
GRN			=	\033[0;32m
RED			=	\033[0;31m
RST			=	\033[0m

NAME = p1

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
	@echo "$(BBLU)=======================> p1 <======================="
	@echo "$(RST)"
.PHONY: print_header

up:
	vagrant up

down:
	vagrant destroy -f


s:
	vagrant ssh $(USERNAME)S

sw:
	vagrant ssh $(USERNAME)SW

.PHONY: all up down s sw