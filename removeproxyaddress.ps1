$OUScope = "OU=Users,DC=Domain,DC=com"
$N = 0
Write-Host "Searching mailboxes in $OUScope...."
foreach($Tmailbox in Get-Mailbox -organizationalunit $OUScope -ResultSize Unlimited) 
 {
 $Tmailbox.EmailAddresses | ?{$_.AddressString -like '*@olddomain.com'} | %{
 Set-Mailbox $Tmailbox -EmailAddresses @{remove=$_}
 Write-host "Removing $_ from $Tmailbox Mailbox"
 $N++
 }
}
