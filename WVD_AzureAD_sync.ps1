$AADUsers=$null
$WVDAppUsers=$null
$AADGroup = ""
$TenantName = " "
$HostPoolName = " "
$ConnectionAssetName = "AzureRunAsConnection"
$AppGroupName = "Desktop Application Group"
$AADTenantId = " "
$subscriptionId = " "


# Collect the credentials from Azure Automation Account Assets
$Connection = Get-AutomationConnection -Name $ConnectionAssetName

# Authenticating to Azure
Clear-AzContext -Force
$AZAuthentication = Connect-AzAccount -ApplicationId $Connection.ApplicationId -CertificateThumbprint $Connection.CertificateThumbprint -ServicePrincipal -TenantId $AADTenantId
$WVDAuthentication = Add-RdsAccount -DeploymentUrl "https://rdbroker.wvd.microsoft.com" -ApplicationId $Connection.ApplicationId -CertificateThumbprint $Connection.CertificateThumbprint -AADTenantId $AADTenantId
$AADAuthentication = Connect-AzureAD -ApplicationId $Connection.ApplicationId -CertificateThumbprint $Connection.CertificateThumbprint -TenantId $AADTenantId

$AADUsers=(Get-AzureADGroupMember -ObjectId $AADGroup | Get-AzureADUser).UserPrincipalName
[array]$WVDAppUsers=(Get-RdsAppGroupUser -TenantName $TenantName -HostPoolName $HostPoolName -AppGroupName $AppGroupName).UserPrincipalName
                                   
                                
Write-output (" AAD WVD Users: " + $AADUsers.count) 
Write-output (" WVD APP Users: " + $WVDAppUsers.count) 

#As one of the two arrays could be empty, we also need to add workarounds in case that is so.. 
#The result of this part is two new arrays (or one depending on scenario) with objects: object.InputObject  == UPN
If ($WVDAppUsers -and $AADUsers){
    [array]$UserSyncStatus = Compare-Object -ReferenceObject ($WVDAppUsers) -DifferenceObject ($AADUsers)
    [array]$usersToDelete=$UserSyncStatus | where {$_.SideIndicator -eq '<='}
    [array]$usersToAdd=$UserSyncStatus | where {$_.SideIndicator -eq '=>'}
    #Write-host $UserSyncStatus 
}elseif ($WVDAppUsers -and (!($AADUsers))) {
    #WVD UPN's found, no AAD UPN's full delete
    $Full=$true
    Write-output ("Full Delete of " + $WVDAppUsers.count + " wvd app users") 
    $usersToDelete = New-Object System.Collections.ArrayList
    ForEach ($UPN in $WVDAppUsers) {
        Remove-RdsAppGroupUser -TenantName $TenantName -HostPoolName $HostPoolName -AppGroupName $AppGroupName -UserPrincipalName $UPN
        }
    }elseif ($AADUsers -and (!($WVDAppUsers))) {
        #AAD UPN's found, and no WVD UPN's, full add
        $Full=$true
        Write-output ("Full add of " + $AADUsers.count + " wvd app users") 
    ForEach ($UPN in $AADUsers) {
        #AddUserToWVDAPP 
        Write-output (" adding " + $UPN) 
        Add-RdsAppGroupUser -TenantName $TenantName -HostPoolName $HostPoolName -AppGroupName $AppGroupName -UserPrincipalName $UPN
    }
}

#ACTUAL Adding  & Removal OF ACCOUNTS 
If ($usersToAdd) {
    Write-output ("Need to add " + $usersToAdd.count + " users")
    ForEach ($UserUPN in $usersToAdd) {
        Write-output (" adding " + $UserUPN.InputObject) 
        #Get The original object from AADUsers array - to be able to extract all required info
        Add-RdsAppGroupUser -TenantName $TenantName -HostPoolName $HostPoolName -AppGroupName $AppGroupName -UserPrincipalName $UserUPN.InputObject
        Write-output "Next user"
    }
}

If ($usersToDelete) {
    Write-output ("Need to remove " + $usersToDelete.count + " users from WVD App")
    ForEach ($UserUPN in $usersToDelete) {
        Write-output  (" removing " + $UserUPN.InputObject) 
        Remove-RdsAppGroupUser -TenantName $TenantName -HostPoolName $HostPoolName -AppGroupName $AppGroupName -UserPrincipalName $UserUPN.InputObject
    }
}
If (!($full) -and (!($usersToAdd)) -and (!($usersToDelete))) {
    Write-output (" ** $AppGroupName Fully Synchronized ** " ) 
}
