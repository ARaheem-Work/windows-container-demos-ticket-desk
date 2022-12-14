# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.
# this file is used for creating Azure AKS Cluster with windows nodepool

# setting variables from variable file
Foreach ($i in $(Get-Content variables.txt)){Set-Variable -Name $i.split("=")[0] -Value $i.split("=").split(" ")[1]}

$subscriptionId = (az account show | ConvertFrom-Json).id
$tenantId = (az account show | ConvertFrom-Json).tenantId

# Set Azure subscription name
Write-Host "Setting Azure subscription to $subscriptionName"  -ForegroundColor Yellow
az account set --subscription $subscriptionName

$aksRgExists = az group exists --name $resourceGroupName

Write-Host "$resourceGroupName exists : $aksRgExists"

if ($aksRgExists -eq $false) {

    # Create resource group name
    Write-Host "Creating resource group $resourceGroupName in region $resourceGroupLocation" -ForegroundColor Yellow
    az group create `
        --name=$resourceGroupName `
        --location=$resourceGroupLocation `
        --output=jsonc
}

$aks = az aks show `
    --name $clusterName `
    --resource-group $resourceGroupName `
    --query name | ConvertFrom-Json

$aksCLusterExists = $aks.Length -gt 0

if ($aksCLusterExists -eq $false) {

    $acrId=az acr show --resource-group $resourceGroupName --name $acrRegistryName --query "id"

    # Create AKS cluster
    Write-Host "Creating AKS cluster $clusterName with resource group $resourceGroupName in region $resourceGroupLocation" -ForegroundColor Yellow
		
	az aks create `
		--resource-group=$resourceGroupName `
		--name=$clusterName `
		--node-count=$workerNodeCount `
		--enable-managed-identity `
		--attach-acr=$acrId `
		--kubernetes-version=$kubernetesVersion `
		--network-plugin=$networkPlugin `
		--load-balancer-sku=$loadBalancerSKU `
		--node-vm-size=$nodeVMSize `
		--generate-ssh-keys `
        --enable-cluster-autoscaler `
        --auto-upgrade-channel="stable" `
        --min-count=$workerNodeCount `
        --max-count=$workerNodeMaxCount `
        --network-policy="calico" `
		--output=jsonc
		
	az aks nodepool add `
		--resource-group=$resourceGroupName `
		--cluster-name=$clusterName `
		--os-type="Windows" `
		--name=$winNodePoolName `
		--node-vm-size=$winNodeVMSize `
		--node-count=$winWorkerNodeCount `
        --enable-cluster-autoscaler `
        --min-count=$winWorkerNodeCount `
        --max-count=$winWorkerNodeMaxCount

}
# Get credentials for newly created cluster
Write-Host "Getting credentials for cluster $clusterName" -ForegroundColor Yellow
az aks get-credentials `
    --resource-group=$resourceGroupName `
    --name=$clusterName `
	--admin `
    --overwrite-existing

Write-Host "Successfully created cluster $clusterName with $workerNodeCount node(s)" -ForegroundColor Green

Write-Host "Creating cluster role binding for Kubernetes dashboard" -ForegroundColor Green

kubectl create clusterrolebinding kubernetes-dashboard `
    -n kube-system `
    --clusterrole=cluster-admin `
    --serviceaccount=kube-system:kubernetes-dashboard