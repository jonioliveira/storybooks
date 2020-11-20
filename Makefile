PROJECT_ID=civic-gate-295923
TF_ACTION?=plan
ZONE?=us-central1-a

run-local:
	@docker-compose up

###

create-tf-backend-bucket:
	@gsutil mb -p $(PROJECT_ID) gs://$(PROJECT_ID)-terraform

###

define get-secret
$(shell gcloud secrets versions access latest --secret=$(1) --project=$(PROJECT_ID))
endef

### 

ENV=staging

tf-create-workspace:
	@cd terraform && \
		terraform workspace new $(ENV)

tf-init:
	@cd terraform && \
		terraform workspace select $(ENV) && \
		terraform init

tf-action:
	@cd terraform && \
		terraform workspace select $(ENV) && \
		terraform $(TF_ACTION) \
		-var-file="./environments/common.tfvars" \
		-var-file="./environments/$(ENV)/config.tfvars" \
		-var="mongodbatlas_private_key=$(call get-secret,atlas_private_key)" \
		-var="atlas_user_password=$(call get-secret,atlas_user_password_$(ENV))" \
		-var="cloudflare_api_token=$(call get-secret,cloudflare_api_token)" \

###

SSH_STRING=joni@storybooks-vm-$(ENV)
GITHUB_SHA?=latest
LOCAL_TAG=storybooks-app:$(GITHUB_SHA)
REMOTE_TAG=gcr.io/$(PROJECT_ID)/$(LOCAL_TAG)

CONTAINER_NAME=storybooks-api
DB_NAME=storybooks
OAUTH_CLIENT_ID=371900076600-vboh7hsai2eq6k079vfq1qsmrf4qu2lk.apps.googleusercontent.com

ssh:
	@gcloud compute ssh $(SSH_STRING) \
		--project=$(PROJECT_ID) \
		--zone=$(ZONE)

ssh-cmd:
	@gcloud compute ssh $(SSH_STRING) \
		--project=$(PROJECT_ID) \
		--zone=$(ZONE) \
		--command="$(CMD)"

build:
	@docker build -t $(LOCAL_TAG) .

push:
	@docker tag $(LOCAL_TAG) $(REMOTE_TAG)
	@docker push $(REMOTE_TAG)

deploy:
	@$(MAKE) ssh-cmd CMD='docker-credential-gcr configure-docker'
	@echo "Pulling container"
	@$(MAKE) ssh-cmd CMD='docker pull $(REMOTE_TAG)'
	@echo "Removing old containers"
	@-$(MAKE) ssh-cmd CMD='docker stop $(CONTAINER_NAME)'
	@-$(MAKE) ssh-cmd CMD='docker rm $(CONTAINER_NAME)'
	@echo "Starting new containers"
	@$(MAKE) ssh-cmd CMD='\
			docker run -d --name=$(CONTAINER_NAME) \
			--restart=unless-stopped \
			-p 80:3000 \
			-e PORT=3000 \
			-e \"MONGO_URI=mongodb+srv://storybook-user-$(ENV):$(call get-secret,atlas_user_password_$(ENV))@storybooks-$(ENV).wckyi.mongodb.net/$(DB_NAME)?retryWrites=true&w=majority\" \
			-e GOOGLE_CLIENT_ID=$(OAUTH_CLIENT_ID) \
			-e GOOGLE_CLIENT_SECRET=$(call get-secret,google_oauth_client_secret) \
			$(REMOTE_TAG) \
			'
