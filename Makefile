APP ?= lambda
PROGRAM ?= default
LOG_GROUP ?=
HOST ?= logs.papertrailapp.com
PORT ?= 1234
DATADOG ?=

ALNUM_LOG_GROUP = $(shell echo $(LOG_GROUP) | sed 's/[^[:alnum:]]/_/g')
ACCOUNT_ID = $(shell aws sts get-caller-identity --output text --query Account)

all: lambda

deps:
	rm -rf node_modules
	npm install

env:
	rm -f env.json
	echo "{\"host\": \"$(HOST)\", \"port\": $(PORT), \"appname\": \"$(APP)\", \"program\": \"$(PROGRAM)\", \"datadog\": \"$(DATADOG)\"}" > env.json

create-zip:
	rm -f code.zip
	zip code.zip -r index.js env.json node_modules

lambda: deps env create-zip
	aws lambda create-function --publish \
	--function-name $(APP)-$(PROGRAM)-to-papertrail \
	--runtime nodejs4.3 \
	--handler index.handler \
	--zip-file fileb://code.zip \
	--role arn:aws:iam::$(ACCOUNT_ID):role/lambda_basic_execution

deploy: deps env create-zip
	aws lambda update-function-code --publish \
	--function-name $(APP)-$(PROGRAM)-to-papertrail \
	--zip-file fileb://code.zip

# log:
# 	ifdef LOG_GROUP

# 		aws lambda add-permission \
# 		--function-name $(APP)-$(PROGRAM)-to-papertrail \
# 		--statement-id $(ALNUM_LOG_GROUP)__$(APP)-$(PROGRAM)-to-papertrail \
# 		--principal logs.$(AWS_DEFAULT_REGION).amazonaws.com \
# 		--action lambda:InvokeFunction \
# 		--source-arn arn:aws:logs:$(AWS_DEFAULT_REGION):$(ACCOUNT_ID):log-group:$(LOG_GROUP):* \
# 		--source-account $(ACCOUNT_ID)

# 		aws logs put-subscription-filter \
# 		--log-group-name $(LOG_GROUP) \
# 		--destination-arn arn:aws:lambda:$(AWS_DEFAULT_REGION):$(ACCOUNT_ID):function:$(APP)-$(PROGRAM)-to-papertrail \
# 		--filter-name LambdaStream_$(APP)-$(PROGRAM)-to-papertrail \
# 		--filter-pattern ""
# 	endif

clean:
	rm -f code.zip env.json

test: env
	docker pull lambci/lambda
	# docker run --name lambda --rm -v $(pwd):/var/task lambci/lambda index.handler '{}'

destroy:
	aws lambda delete-function \
	--function-name $(APP)-$(PROGRAM)-to-papertrail
