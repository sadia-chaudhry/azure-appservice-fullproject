#!/bin/bash
set -e

# ---- Config ----
RESOURCE_GROUP="az104-appservice-rg"
LOCATION="francecentral"
APP_NAME="sadia-az104-webapp"
STORAGE_ACCOUNT="sadiaaz104backups"
CONTAINER_NAME="appservice-backups"

# ---- Storage account + container for backups ----
echo "Creating storage account..."
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS

echo "Creating backup container..."
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT

# ---- Generate a fresh SAS URL and trigger a backup ----
echo "Generating SAS token..."
EXPIRY=$(date -v+2d +%Y-%m-%dT%H:%MZ)
SAS=$(az storage container generate-sas \
  --account-name $STORAGE_ACCOUNT \
  --name $CONTAINER_NAME \
  --permissions racwd \
  --expiry $EXPIRY \
  --output tsv)
CONTAINER_URL="https://${STORAGE_ACCOUNT}.blob.core.windows.net/${CONTAINER_NAME}?${SAS}"

echo "Triggering manual backup..."
az webapp config backup create \
  --resource-group $RESOURCE_GROUP \
  --webapp-name $APP_NAME \
  --backup-name "az104-manual-backup-$(date +%s 2>/dev/null || echo 1)" \
  --container-url "$CONTAINER_URL"

# ---- Networking: restrict access to a single IP ----
echo "Configuring access restriction..."
MY_IP=$(curl -4 -s ifconfig.me)
echo "Allowing IP: $MY_IP"

az webapp config access-restriction add \
  --resource-group $RESOURCE_GROUP \
  --name $APP_NAME \
  --rule-name 'allow-my-ip' \
  --action Allow \
  --ip-address "${MY_IP}/32" \
  --priority 100

az resource update \
  --resource-group $RESOURCE_GROUP \
  --name $APP_NAME \
  --resource-type "Microsoft.Web/sites" \
  --set properties.siteConfig.ipSecurityRestrictionsDefaultAction=Deny

echo "Backup and networking setup complete!"
