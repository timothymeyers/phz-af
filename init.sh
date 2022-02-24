## Run in az Cloud Shell (for now)


### Create storage account for tf state

STATE_RG=phopstfstates
STATE_ACCOUNT=phopstf
STATE_CONTAINER=tfstatedevops
REGION=eastus
SKU=Standard_LRS


az group create -n $STATE_RG -l $REGION
az storage account create -n $STATE_ACCOUNT -g $STATE_RG -l $REGION --sku $SKU
az storage container create -n $STATE_CONTAINER --account-name $STATE_ACCOUNT

### Create Service Principle

SP_NAME=phopstfsp

az ad sp create-for-rbac --name $SP_NAME

### Make note of this output and save as GH Secrets