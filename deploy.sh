#!/bin/bash
set -e

# ---- Config ----
RESOURCE_GROUP="az104-appservice-rg"
LOCATION="francecentral"
PLAN_NAME="az104-appservice-plan"
APP_NAME="sadia-az104-webapp"
AUTOSCALE_NAME="az104-appservice-autoscale"

# ---- Resource Group ----
echo "Creating resource group..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# ---- App Service Plan (Standard S1, required for slots + autoscale) ----
echo "Creating App Service Plan (Standard S1)..."
az appservice plan create \
  --name $PLAN_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku S1 \
  --is-linux

# ---- Web App ----
echo "Creating Web App..."
az webapp create \
  --resource-group $RESOURCE_GROUP \
  --plan $PLAN_NAME \
  --name $APP_NAME \
  --runtime "NODE|24-lts"

# ---- Deploy production code ----
echo "Packaging and deploying production app..."
zip -r -j production.zip production-app/index.js production-app/package.json
az webapp deploy \
  --resource-group $RESOURCE_GROUP \
  --name $APP_NAME \
  --src-path production.zip \
  --type zip

# ---- Staging slot ----
echo "Creating staging deployment slot..."
az webapp deployment slot create \
  --resource-group $RESOURCE_GROUP \
  --name $APP_NAME \
  --slot staging

echo "Packaging and deploying staging app..."
zip -r -j staging.zip staging-app/index.js staging-app/package.json
az webapp deploy \
  --resource-group $RESOURCE_GROUP \
  --name $APP_NAME \
  --slot staging \
  --src-path staging.zip \
  --type zip

# ---- Swap staging into production ----
echo "Swapping staging into production..."
az webapp deployment slot swap \
  --resource-group $RESOURCE_GROUP \
  --name $APP_NAME \
  --slot staging \
  --target-slot production

# ---- Autoscale ----
echo "Configuring autoscale..."
PLAN_ID=$(az appservice plan show --resource-group $RESOURCE_GROUP --name $PLAN_NAME --query id --output tsv)

az monitor autoscale create \
  --resource-group $RESOURCE_GROUP \
  --resource $PLAN_ID \
  --name $AUTOSCALE_NAME \
  --min-count 1 \
  --max-count 3 \
  --count 1

az monitor autoscale rule create \
  --resource-group $RESOURCE_GROUP \
  --autoscale-name $AUTOSCALE_NAME \
  --condition "CpuPercentage > 70 avg 5m" \
  --scale out 1

az monitor autoscale rule create \
  --resource-group $RESOURCE_GROUP \
  --autoscale-name $AUTOSCALE_NAME \
  --condition "CpuPercentage < 30 avg 5m" \
  --scale in 1

echo "Deployment complete!"
