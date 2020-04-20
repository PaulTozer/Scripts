$Recipients = Get-Mailbox -ResultSize Unlimited | Where {$_.EmailAddresses -like "X400:*"}
foreach ($Recipient in $Recipients)
{
[array]$AllEmailAddresses = $Recipient.EmailAddresses
[array]$NoX400Addresses = $Recipient.EmailAddresses | Where {$_ -notlike "X400:*"}
Set-Mailbox -Identity $Recipient.Identity -EmailAddresses $NoX400Addresses
}
