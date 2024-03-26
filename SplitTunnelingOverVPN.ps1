##******************************************************************
##
## Revision date: 2024.03.13
##
## Copyright (c) 2023-2024 PC-Évolution enr.
## This code is licensed under the GNU General Public License (GPL).
##
## THIS CODE IS PROVIDED *AS IS* WITHOUT WARRANTY OF
## ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY
## IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR
## PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.
##
##******************************************************************

param (
	[Parameter(mandatory = $true, HelpMessage = 'Set the connexion name as it will appear in Windows menus')]
	[string]$MyVPN,
	[Parameter()]
	[string]$MyVPNType = "IKEv2",
	[parameter(mandatory = $true, HelpMessage = 'Set the fully qualified host name of the VPN server')]
	[string]$TargetServer,
	[parameter(mandatory = $true, HelpMessage = 'Enter a comma separated list of remote subnets')]
	[string[]]$TargetNetworks
)

# Sanity check: is the target server known?
try {
	$DNS = Resolve-DnsName -Name $TargetServer -DnsOnly -ErrorAction Stop
	Write-Output "$TargetServer resolves to [ $($DNS.IPAddress) ]"
	Write-Output
}
catch {
	Write-Warning -Message "$TargetServer does not resolve in DNS. Terminating ..."
	Pause
	Exit 911
}

# The focus of this code is Split Tunneling, not security and/or a specific tunnel type.
# Proper routes will be added on a live connection regardless of tunnel type and/or security.

# Get the VPN interface: create one if needed.
Try {
	# Assume an existing VPN connection is properly configured.
	$PPPInterface = Get-VpnConnection -Name $MyVPN -ErrorAction Stop
}
Catch {
 $PPPInterface = Add-VpnConnection -Name $MyVPN -ServerAddress $TargetServer -TunnelType $MyVPNType  -EncryptionLevel Required -RememberCredential -SplitTunneling
	# Somehow, the output of the above is always $Null
	$PPPInterface = Get-VpnConnection -Name $MyVPN
	Set-VpnConnectionIPsecConfiguration -ConnectionName $MyVPN `
		-AuthenticationTransformConstants SHA256128 `
		-CipherTransformConstants AES256 `
		-EncryptionMethod AES256 `
		-IntegrityCheckMethod SHA256 `
		-PfsGroup None `
		-DHGroup Group14 `
		-PassThru -Force
	Write-Warning "Please connect to this remote server and save your credentials before routes can be attached to this connection."
	Write-Warning ""
}

# Issue warning if older NegotiateDH2048_AES256 is configured
Try {
	Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\RasMan\Parameters -Name NegotiateDH2048_AES256 -ErrorAction Stop
	Write-Warning "Please review the RASMan NegotiateDH2048_AES256 parameter."
	Write-Warning "For example, you may have to delete this value if DH group 2 is not available from the remote server."
	Write-Warning "Please see https://www.stevenjordan.net/2016/09/secure-ikev2-win-10.html to see how this parameter was"
	Write-Warning "used to enable secure IPsec on Windows clients."
	Write-Warning "Also see https://wiki.strongswan.org/issues/3021 to understand the negative effects of this parameter."
}
Catch {
 # This is the expected result
}


if ($PPPInterface.ConnectionStatus -eq "Disconnected") {
	ForEach ($TargetNetwork in $TargetNetworks) { 
		# Windows maintains "persistent" (accross reboot) routing tables that can be modified during the "active" session
		# and no clear way to know what is what. If such rouute(s) exist, remove them.
		Try {
			Remove-NetRoute -DestinationPrefix $TargetNetwork -PolicyStore ActiveStore -Confirm:$False -ErrorAction Stop
			Write-Warning "Active route to $TargetNetwork was removed while $MyVPN is offline. There may be a routing issue."
		}
		Catch {
			# This is the expected case.
			Write-Output "There is no active route to $TargetNetwork."
		}
		Try	{
			Remove-NetRoute -DestinationPrefix $TargetNetwork -PolicyStore PersistentStore -Confirm:$False -ErrorAction Stop
			Write-Warning "Persistent route to $TargetNetwork was removed while $MyVPN is offline. There may be a routing issue."
		}
		Catch {
			# This is also the expected case.
			Write-Output "There is no persistent route to $TargetNetwork."
		}
		# Add routes BEFORE the connection is established. These routes are only valid during the active session.
		$Route = Add-VpnConnectionRoute -ConnectionName $MyVPN -DestinationPrefix $TargetNetwork -PassThru
	}
	# Invoke rasdial to establish a connection.
	$code = (Start-Process rasdial -NoNewWindow -ArgumentList $MyVPN -RedirectStandardOutput \\.\NUL -PassThru -Wait).ExitCode
	if ( $code -ne 0) {
		Write-Warning "Please use the Windows interface to connect to $MyVPN"
		Write-Warning "RAS Dial error code: $code"
		Exit 911
	}
}
else {
	ForEach ($TargetNetwork in $TargetNetworks) { 
		# Windows maintains "persistent" (accross reboot) routing tables that can be modified during the "active" session
		# and no clear way to know what is what. If such route(s) exist, remove them and add a temporary route.
		# This is also required if the IKEv2 mobile client is receiving different IP addresses from the VPN address pool.
			
		Try {
			$Route = Get-NetRoute -DestinationPrefix $TargetNetwork -ErrorAction Stop
			if ( $Route.InterfaceAlias -ne $MyVPN ) {
				Write-Warning "There is a routing issue: $TargetNetwork is currently handled by $Route.InterfaceAlias"
			}
		}
		Catch { Write-Warning "There is a routing issue: $TargetNetwork is not an active route. Disconnect from $MyVPN and rerun this script." }
	}
}

# Get the IP assigned from the remote VPN address pool
$TunnelIP = (Get-NetIPAddress | Where-Object { $_.InterfaceAlias -eq $MyVPN }).IPAddress

# Display basic IP routing information
Write-Output
Write-Output "Local VPN Routing address: $TunnelIP"
Get-NetRoute -State Alive -InterfaceAlias $MyVPN | Format-Table -AutoSize
Write-Output ""

# Display whatever was setup as DNS servers for the remote subnet
$RemoteDNSServers = (Get-NetIPConfiguration -InterfaceAlias $MyVPN).DNSServer | Select-Object -ExpandProperty ServerAddresses
Write-Output "Remote DNS Servers: $RemoteDNSServers"
ForEach ($Server in $RemoteDNSServers) {
	Find-NetRoute -RemoteIPAddress $Server | Format-Table $Server, DestinationPrefix, @{Label = 'Gateway'; Expression = { $_.IPAddress } }, Store -AutoSize
}

Pause

