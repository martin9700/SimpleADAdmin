$hostEntry=New-Object -TypeName System.Net.IPHostEntry
$configurationContainer = ([adsi] "LDAP://RootDSE").Get("ConfigurationNamingContext")
$partitions = ([adsi] "LDAP://CN=Partitions,$configurationContainer").psbase.children
"Domain`tDomainController`tIPAddress" #| Out-File -FilePath "DomainControllers.txt"
foreach($partition in $partitions)
{
 if($partition.netbiosName -ne ""){
  "DCs in the " + $partition.netbiosName + " Domain"
  $partitionDN=$partition.ncName
  $dcContainer=[adsi] "LDAP://ou=domain controllers,$partitionDN"
  $dcs = $dcContainer.psbase.children
  foreach($dc in $dcs){
   $hostEntry= [System.Net.Dns]::GetHostByName($dc.dnsHostName)
   "`t" + $dc.dnsHostName + "`t" + $hostEntry.AddressList[0].IPAddressToString
   "$($partition.netbiosName)`t$($dc.dnsHostName)`t$($hostEntry.AddressList[0].IPAddressToString)"# | Out-File -FilePath "DomainControllers.txt" -Append
  }
 }
}