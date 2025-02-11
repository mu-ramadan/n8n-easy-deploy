.PHONY: deploy update backup restore backupwc restorewc help

deploy:
	./scripts/n8n-ctl.sh deploy

update:
	./scripts/n8n-ctl.sh update

backup:
	./scripts/n8n-ctl.sh backup

restore:
	./scripts/n8n-ctl.sh restore

backupwc:
	./scripts/n8n-ctl.sh backupwc

restorewc:
	./scripts/n8n-ctl.sh restorewc

help:
	./scripts/n8n-ctl.sh help
