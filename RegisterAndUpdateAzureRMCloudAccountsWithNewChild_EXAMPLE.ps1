[cmdletbinding()]

$accountEndpoint = "us-3.rightscale.com" # https://docs.rightscale.com/api/general_usage.html#endpoints
$masterAccountId = "" # Your CMP Master Account ID
$refreshToken = "" # https://docs.rightscale.com/cm/dashboard/settings/account/enable_oauth#steps

# Create an Azure Active Directory Application: https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#create-an-azure-active-directory-application
# Retrieve an Azure Active Directory Application Tenant ID, Client ID, and Client Secret: https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#ge
$tenantId = ""
$cliendId = ""
$clientSecret = ""

## CSV File Syntax
##
## subscription_id,subscription_name
## <Subscription GUID>,<Subscription Name>
##
$pathToCsv = "path-to-csv-file.csv"

if(Test-Path -Path $pathToCsv) {
    $subscriptions = Import-Csv -Path $pathToCsv

    if($subscriptions.subscription_id -and $subscriptions.subscription_name) {

        Write-Verbose "Iterating over $($subscriptions.count) Azure Subscriptions..."
        $subscriptions | ForEach-Object {
            .\RegisterAndUpdateAzureRMCloudAccountsWithNewChild.ps1 `
                -accountEndpoint $accountEndpoint `
                -masterAccountId $masterAccountId `
                -refreshToken $refreshToken `
                -clientId $cliendId `
                -clientSecret $clientSecret `
                -tenantId $tenantId `
                -subscriptionId $_.subscription_id`
                -subscriptionName $_.subscription_name
        }
        
    }
    else {
        Write-Warning "Please verify CSV is properly formatted and contains values!"
    }

}
else {
    Write-Warning "CSV does not exist @ $pathToCsv !"
}
