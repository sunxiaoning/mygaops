init-env:
	@echo "Init env ..."

prepare:
	@echo "Prepare workspace ..."

install-repo:
	@echo "Install repo ..."
	hack/install.sh repo

install-app: install-repo
	@echo "Install app ..."
	hack/install.sh app

install-conf:
	@echo "Install conf ..."
	hack/install.sh conf

install: install-app install-conf

start:
	@echo "Start server ..."
	hack/run.sh start

init-server:
	@echo "Init server ..."
	hack/run.sh init

check-node:
	@echo "Check node mysql-wsrep status ..."
	hack/run.sh check-node

autorun: install start

autoboot: autorun init-server

reinit:
	@echo "Reinit server ..."
	hack/run.sh reinit

stop:
	@echo "Stop server ..."
	hack/run.sh stop

restart: stop start





