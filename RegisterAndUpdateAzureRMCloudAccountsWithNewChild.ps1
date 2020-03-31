# The following example will allow you to register/update your AzureRM Subscription credentials with the Flexera Cloud Management Platform

# Cloud Href Reference: https://docs.rightscale.com/api/api_1.5_examples/cloudaccounts.html
# API Docs: https://reference.rightscale.com/api1.5/resources/ResourceCloudAccounts.html
# Refresh Token: https://docs.rightscale.com/cm/dashboard/settings/account/enable_oauth#steps
# Create an Azure Active Directory Application: https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#create-an-azure-active-directory-application
# Retrieve an Azure Active Directory Application Tenant ID, Client ID, and Client Secret: https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#get-values-for-signing-in

param(
    $accountEndpoint = "us-3.rightscale.com", # Cloud Management Endpoints: https://docs.rightscale.com/api/general_usage.html#endpoints
    $masterAccountId = "", # Your CMP Master Account ID
    $refreshToken = "", # Your Refresh Token https://docs.rightscale.com/cm/dashboard/settings/account/enable_oauth#steps
    $clientId = "", # Azure Application Client ID
    $clientSecret = "", # Secret for the application
    $tenantId = "", # Azure AD Tenant ID for the application
    $subscriptionId = "", # Azure Subscription the application has access to and that you want to manage in CMP
    $subscriptionName = "" # Azure Subscription Name (will be the name of the new RS Child Account)
)

Add-Type -AssemblyName System.Web
$shardCluster = $accountEndpoint.split('.')[0].split('-')[-1]
$clientIdEncoded = [System.Web.HttpUtility]::UrlEncode($clientId)
$clientSecretEncoded = [System.Web.HttpUtility]::UrlEncode($clientSecret)
$tenantIdEncoded = [System.Web.HttpUtility]::UrlEncode($tenantId)
$subscriptionIdEncoded = [System.Web.HttpUtility]::UrlEncode($subscriptionId)

# Azure Cloud Href Reference: https://docs.rightscale.com/api/api_1.5_examples/cloudaccounts.html#supported-clouds-and-parameters-microsoft-azure
$cloudHrefs = @(
    "/api/clouds/3518", # AzureRM West US
    "/api/clouds/3519", # AzureRM Japan East
    "/api/clouds/3520", # AzureRM Southeast Asia
    "/api/clouds/3521", # AzureRM Japan West
    "/api/clouds/3522", # AzureRM East Asia
    "/api/clouds/3523", # AzureRM East US
    "/api/clouds/3524", # AzureRM West Europe
    "/api/clouds/3525", # AzureRM North Central US
    "/api/clouds/3526", # AzureRM Central US
    "/api/clouds/3527", # AzureRM Canada Central
    "/api/clouds/3528", # AzureRM North Europe
    "/api/clouds/3529", # AzureRM Brazil South
    "/api/clouds/3530", # AzureRM Canada East
    "/api/clouds/3531", # AzureRM East US 2
    "/api/clouds/3532", # AzureRM South Central US
    "/api/clouds/3537", # AzureRM Australia East
    "/api/clouds/3538", # AzureRM Australia Southeast
    "/api/clouds/3546", # AzureRM West US 2
    "/api/clouds/3547", # AzureRM West Central US
    "/api/clouds/3567", # AzureRM UK South
    "/api/clouds/3568", # AzureRM UK West
    "/api/clouds/3569", # AzureRM West India
    "/api/clouds/3570", # AzureRM Central India
    "/api/clouds/3571", # AzureRM South India
    "/api/clouds/3749", # AzureRM Korea Central
    "/api/clouds/3756"  # AzureRM Korea South
)

$token = Invoke-RestMethod -Method Post -Uri "https://$($accountEndpoint)/api/oauth2" `
    -Headers @{ "X-API-Version"="1.5"; "X-Account"=$masterAccountId } `
    -Body @{
        grant_type="refresh_token";
        refresh_token=$refreshToken
    }

if (-not($token)) {
    Write-Warning "Error retrieving access token!"
    EXIT 1
}

Write-Output "Subscription Name: $subscriptionName"
Write-Output "Subscription ID: $subscriptionId"

$currentChildAccounts = Invoke-RestMethod -Method Get `
    -Uri "https://$($accountEndpoint)/api/child_accounts" `
    -Headers @{ "X-API-Version"="1.5"; "Authorization"="Bearer $($token.access_token)"; "X-Account"=$masterAccountId }

if ($currentChildAccounts.name -notcontains $subscriptionName){
    # Create RS Child Account
    Write-Output "Creating RS Child Account.."
    Invoke-RestMethod -Method Post `
        -Uri "https://$($accountEndpoint)/api/child_accounts" `
        -Headers @{ "X-API-Version"="1.5"; "Authorization"="Bearer $($token.access_token)"; "X-Account"=$masterAccountId } `
        -Body "child_account[name]=$subscriptionName&child_account[cluster_href]=/api/clusters/$shardCluster"

    $currentChildAccounts = Invoke-RestMethod -Method Get `
        -Uri "https://$($accountEndpoint)/api/child_accounts" `
        -Headers @{ "X-API-Version"="1.5"; "Authorization"="Bearer $($token.access_token)"; "X-Account"=$masterAccountId }
}

$accountId = (($currentChildAccounts | where name -eq $subscriptionName).links | where rel -eq self).href.split("/")[3]
Write-Output "RS Child Account ID: $accountId"

$currentCloudAccounts = Invoke-RestMethod -Method Get `
    -Uri "https://$($accountEndpoint)/api/cloud_accounts" `
    -Headers @{ "X-API-Version"="1.5"; "Authorization"="Bearer $($token.access_token)"; "X-Account"=$accountId }

$currentCloudAccounts = $currentCloudAccounts | Select-Object created_at, updated_at, `
    @{name="self";expression={$_.links | Where-Object {$_.rel -eq 'self'} | Select-Object -ExpandProperty href}},`
    @{name="cloud";expression={$_.links | Where-Object {$_.rel -eq 'cloud'} | Select-Object -ExpandProperty href}},`
    @{name="account";expression={$_.links | Where-Object {$_.rel -eq 'account'} | Select-Object -ExpandProperty href}}


$successResults = 0
$errorResults = 0
foreach ($cloudHref in $cloudHrefs) {
    Write-Output "Cloud Href: $cloudHref"
    if($currentCloudAccounts.cloud -contains $cloudHref) {
        # Cloud/Region is already registered, update cloud account
        Write-Output "CLOUDS ALREADY CONNECTED! Updating Connections.."
        $requestVerb = "Put"
        $url = $currentCloudAccounts | Where-Object {$_.cloud -eq $cloudHref} | Select-Object -ExpandProperty self
        $body = "cloud_account[creds][client_id]=$clientIdEncoded&cloud_account[creds][client_secret]=$clientSecretEncoded&cloud_account[creds][tenant_id]=$tenantIdEncoded"
    }
    else {
        # Cloud/Region is not registered, create cloud account
        Write-Output "Connecting subscription.."
        $requestVerb = "Post"
        $url = "/api/cloud_accounts"
        $body = "cloud_account[cloud_href]=$cloudHref&cloud_account[creds][client_id]=$clientIdEncoded&cloud_account[creds][client_secret]=$clientSecretEncoded&cloud_account[creds][tenant_id]=$tenantIdEncoded&cloud_account[creds][subscription_id]=$subscriptionIdEncoded"
    }

    try {
        $result = Invoke-RestMethod -Method $requestVerb `
            -Uri "https://$($accountEndpoint)$($url)" `
            -ContentType "application/x-www-form-urlencoded" `
            -Headers @{ "X-API-Version"="1.5"; "Authorization"="Bearer $($token.access_token)"; "X-Account"=$accountId } `
            -Body $body -ErrorAction SilentlyContinue -ErrorVariable cloudRegResponse
        if($result) {
            $successResults++
        }
        else {
            $errorResults++
        }
    }
    catch {
        Write-Warning "Error setting cloud credentials! $_"
        $errorResults++
    }
}

Write-Output "Creating CM Credentials.."
# Create Credentials

Invoke-RestMethod -Method "Post" `
        -Uri "https://$($accountEndpoint)/api/credentials" `
        -ContentType "application/x-www-form-urlencoded" `
        -Headers @{ "X-API-Version"="1.5"; "Authorization"="Bearer $($token.access_token)"; "X-Account"=$accountId } `
        -Body "credential[name]=AZURE_TENANT_ID&credential[value]=$tenantIdEncoded&credential[description]=Azure Tenant ID"

Invoke-RestMethod -Method "Post" `
        -Uri "https://$($accountEndpoint)/api/credentials" `
        -ContentType "application/x-www-form-urlencoded" `
        -Headers @{ "X-API-Version"="1.5"; "Authorization"="Bearer $($token.access_token)"; "X-Account"=$accountId } `
        -Body "credential[name]=AZURE_SUBSCRIPTION_ID&credential[value]=$subscriptionIdEncoded&credential[description]=Azure Subscription Id"

Invoke-RestMethod -Method "Post" `
        -Uri "https://$($accountEndpoint)/api/credentials" `
        -ContentType "application/x-www-form-urlencoded" `
        -Headers @{ "X-API-Version"="1.5"; "Authorization"="Bearer $($token.access_token)"; "X-Account"=$accountId } `
        -Body "credential[name]=AZURE_APPLICATION_ID&credential[value]=$clientId&credential[description]=Azure Application ID for Policies and Plugins"

Invoke-RestMethod -Method "Post" `
        -Uri "https://$($accountEndpoint)/api/credentials" `
        -ContentType "application/x-www-form-urlencoded" `
        -Headers @{ "X-API-Version"="1.5"; "Authorization"="Bearer $($token.access_token)"; "X-Account"=$accountId } `
        -Body "credential[name]=AZURE_APPLICATION_KEY&credential[value]=$clientSecret&credential[description]=Azure Application Key for Policies and Plugins"
