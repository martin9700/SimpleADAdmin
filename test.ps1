$User = "mpugh"
$DN = "martin"
$searcher = [adsisearcher]"(&(objectCategory=person)(objectClass=user)(samaccountname=$user))"
$U = $searcher.FindOne()
#$U | Select @{Name="SamAccountName";Expression={ $_.properties.samaccountname }}
#$U.Count


$guid = $U[0].properties.objectguid[0]
$guidInHEX = [string]::Empty
$guid | % { $guidInHEX += '{0:X}' -f $_ }
$guidInHEX


[System.BitConverter]::ToString([byte[]]$U.properties.objectguid[0].Clone()).Replace('-',' ')

new-object guid(,$U.properties.objectguid[0])