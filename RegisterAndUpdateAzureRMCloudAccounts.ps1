# The following example will allow you to register/update your AzureRM Subscription credentials with the Flexera Cloud Management Platform

# Cloud Href Reference: https://docs.rightscale.com/api/api_1.5_examples/cloudaccounts.html
# API Docs: https://reference.rightscale.com/api1.5/resources/ResourceCloudAccounts.html
# Refresh Token: https://docs.rightscale.com/cm/dashboard/settings/account/enable_oauth#steps
# Create an Azure Active Directory Application: https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#create-an-azure-active-directory-application
# Retireve an Azure Active Directory Application Tenant ID, Client ID, and Client Secret: https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#get-values-for-signing-in

$accountEndpoint = "<YOUR_ACCOUNT_ENDPOINT>" # Cloud Management Endpoints: https://docs.rightscale.com/api/general_usage.html#endpoints
$accountId = "<YOUR_ACCOUNT_NUMBER>" # Your CMP Account ID
$refreshToken = "<YOUR_REFRESH_TOKEN>" # Your Refresh Token https://docs.rightscale.com/cm/dashboard/settings/account/enable_oauth#steps
$clientId = "<YOUR_AZURE_APPLICATION_CLIENT_ID>" # Azure Application Client ID
$clientSecret = "<YOUR_AZURE_APPLICATION_CLIENT_SECRET>" # Secret for the application
$tenantId = "<YOUR_AZURE_TENANT_ID>" # Azure AD Tenant ID for the application
$subscriptionId = "<YOUR_AZURE_SUBSCRIPTION_ID>" # Azure Subscription the application has access to and that you want to manage in CMP

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
    -Headers @{ "X-API-Version"="1.5"; "X-Account"=$accountId } `
    -Body @{
        grant_type="refresh_token";
        refresh_token=$refreshToken
    }

$currentCloudAccounts = Invoke-RestMethod -Method Get `
    -Uri "https://$($accountEndpoint)/api/cloud_accounts" `
    -Headers @{ "X-API-Version"="1.5"; "Authorization"="Bearer $($token.access_token)"; "X-Account"=$accountId }

$currentCloudAccounts = $currentCloudAccounts | Select-Object created_at, updated_at, `
    @{name="self";expression={$_.links | Where-Object {$_.rel -eq 'self'} | Select-Object -ExpandProperty href}},`
    @{name="cloud";expression={$_.links | Where-Object {$_.rel -eq 'cloud'} | Select-Object -ExpandProperty href}},`
    @{name="account";expression={$_.links | Where-Object {$_.rel -eq 'account'} | Select-Object -ExpandProperty href}}


foreach ($cloudHref in $cloudHrefs) {
    if($currentCloudAccounts.cloud -contains $cloudHref) {
        # Cloud/Region is already registered, update cloud account
        $requestVerb = "Put"
        $url = $currentCloudAccounts | Where-Object {$_.cloud -eq $cloudHref} | Select-Object -ExpandProperty self
        $body = "cloud_account[creds][client_id]=$clientIdEncoded&cloud_account[creds][client_secret]=$clientSecretEncoded&cloud_account[creds][tenant_id]=$tenantIdEncoded"
    }
    else {
        # Cloud/Region is not registered, create cloud account
        $requestVerb = "Post"
        $url = "/api/cloud_accounts"
        $body = "cloud_account[cloud_href]=$cloudHref&cloud_account[creds][client_id]=$clientIdEncoded&cloud_account[creds][client_secret]=$clientSecretEncoded&cloud_account[creds][tenant_id]=$tenantIdEncoded&cloud_account[creds][subscription_id]=$subscriptionIdEncoded"
    }

    Invoke-RestMethod -Method $requestVerb `
        -Uri "https://$($accountEndpoint)$($url)" `
        -ContentType "application/x-www-form-urlencoded" `
        -Headers @{ "X_API_VERSION"="1.5"; "Authorization"="Bearer $($token.access_token)"; "X-Account"=$accountId } `
        -Body $body
}
