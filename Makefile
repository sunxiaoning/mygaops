init-env:
	@echo "Init env ..."

prepare:
	@echo "Prepare workspace ..."

install-repo:
	@echo "Install repo ..."
	hack/install.sh repo

install-app:
	$(MAKE) install-repo
	@echo "Install app ..."
	hack/install.sh app

install-conf:
	@echo "Install conf ..."
	hack/install.sh conf

install: 
	$(MAKE) install-app
	$(MAKE) install-conf

start:
	@echo "Start server ..."
	hack/run.sh start

init-server:
	@echo "Init server ..."
	hack/run.sh init

reinit-server:
	@echo "Reinit server ..."
	hack/run.sh reinit

reset-password:
	hack/run.sh reset-password

autorun: 
	$(MAKE) install 
	$(MAKE) start

autoboot: 
	$(MAKE) autorun 
	$(MAKE) init-server

check-node:
	@echo "Check node mysql-wsrep status ..."
	hack/run.sh check-node

check-cluster:
	@echo "Check cluster mysql-wsrep status ..."
	hack/run.sh check-cluster
	
stop:
	@echo "Stop server ..."
	hack/run.sh stop

restart: 
	(MAKE) stop 
	(MAKE) start

uninstall-app:
	@echo "Uninstall app ..."
	hack/uninstall.sh app





