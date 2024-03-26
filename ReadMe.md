# Split tunneling over VPN in Windows 10/11 clients

**Caution: The focus of this code is Split Tunneling, not security and/or a specific tunnel type. A general discussion of this networking configuration is found in *[Wikipedia](https://en.wikipedia.org/wiki/Split_tunneling)*.**

Add a connection specific routing table to the user's session. Presume that the VPN server supply remove DNS server(s) and a domain search list. Unlike NetBIOS environments, all references by name to remote devices must be explicitly qualified. Otherwise, remote devices must be accessed by their IP address.


Usage: SplitTunnelingOverVPN -MyVpn \<RAS Entry name\> -MyVPNType \<Type\> -TargetServer \<FullyQualifiedHostName\> -TargetNetworks Subnet1,...,Subnetn

Where:
- -MyVpn is the connexion name used to connect to the target server.
- -MyVPNType is the VPN protocol. Accepted values are: Pptp, L2tp, Sstp, Ikev2, Automatic. The default value is IKEv2 and the parameter can be omitted.
- -TargetServer is the fully qualified host name of the remote server. This hostname must resolve in DNS.
- -TargetNetworks is a list of remote subnet accessible through this VPN connection.

The script presumes the VPN is already configured and that the user credentials were saved on the first successful connection.

<details>
<Summary>However, if this is not the case:</Summary>
A VPN connection is created with the following parameters:

- AuthenticationTransformConstants : SHA256128
- CipherTransformConstants         : AES256
- DHGroup                          : Group14
- IntegrityCheckMethod             : SHA256
- PfsGroup                         : None
- EncryptionMethod                 : AES256

These are the default parameters used by IoS and MAC devices for IKEv2 connectors.

The user is then invited to connect to the remote server and save the credentials before routes can be attached to this connection.
</details>

Windows routes over VPN **must be configured while the VPN is disconnected**.


Example:
<details>
<Summary>Create a new VPN entry:</Summary>

````
PS C:\Users\ThisUser\Desktop> .\SplitTunnelingOverVPN.ps1 -MyVpn Example -TargetServer <host.FQDN> -TargetNetworks 10.0.0.0/24,192.168.36.0/24


AuthenticationTransformConstants : SHA256128
CipherTransformConstants         : AES256
DHGroup                          : Group14
IntegrityCheckMethod             : SHA256
PfsGroup                         : None
EncryptionMethod                 : AES256

WARNING : Please connect to this remote server and save your credentials before routes can be attached to this
connection.
WARNING :
There is no active route to 10.0.0.0/24.
There is no persistent route to 10.0.0.0/24.
There is no active route to 192.168.36.0/24.
There is no persistent route to 192.168.36.0/24.
WARNING : Please use the Windows interface to connect to Example
WARNING : RAS Dial error code: 703
````
</details>

Disconnect from the target VPN (and re-issue the command if this was just created). The script will add routes to the subnets enumerated in the command, connect to the remote server and display the applicable routing table. The routes are attached to the VPN connection, not to the gateway IP of the remote server, 192.168.63.241/32 in the following example:

````

PS C:\Users\ThisUser\Desktop> .\SplitTunnelingOverVPN.ps1 -MyVpn Example -TargetServer  <host.FQDN> -TargetNetworks 10.0.0.0/24,192.168.36.0/24
host.FQDN resolves to [ aa.bb.cc.dd ]

There is no active route to 10.0.0.0/24.
There is no persistent route to 10.0.0.0/24.
There is no active route to 192.168.36.0/24.
There is no persistent route to 192.168.36.0/24.

Local VPN Routing address: 192.168.63.241

ifIndex DestinationPrefix  NextHop RouteMetric ifMetric PolicyStore
------- -----------------  ------- ----------- -------- -----------
52      255.255.255.255/32 0.0.0.0         256 25       ActiveStore
52      224.0.0.0/4        0.0.0.0         256 25       ActiveStore
52      192.168.63.255/32  0.0.0.0         256 25       ActiveStore
52      192.168.63.241/32  0.0.0.0         256 25       ActiveStore
52      192.168.63.0/24    0.0.0.0           1 25       ActiveStore
52      192.168.36.255/32  0.0.0.0         256 25       ActiveStore
52      192.168.36.0/24    0.0.0.0           1 25       ActiveStore
52      10.0.0.255/32      0.0.0.0         256 25       ActiveStore
52      10.0.0.0/24        0.0.0.0           1 25       ActiveStore



Remote DNS Servers: 10.0.0.2

10.0.0.2 DestinationPrefix Gateway              Store
-------- ----------------- -------              -----
                           192.168.63.241 ActiveStore
         10.0.0.0/24                      ActiveStore


Press Enter to continue...:

````

<details>
<Summary>Example: ping remote device by hostname</Summary>
Name resolution for the remote hosts is done by the remote DNS server(s) only if the conection suffix is explicitly specified:

````

PS C:\Users\ThisUser\Desktop> ping TL-SG2008P.FQDN

Pinging TL-SG2008P.FQDN [10.0.0.3] with 32 bytes of data:
Pinging 10.0.0.3 with 32 bytes of data:
Reply from 10.0.0.3: bytes=32 time=20 ms TTL=63
Reply from 10.0.0.3: bytes=32 time=22 ms TTL=63
Reply from 10.0.0.3: bytes=32 time=25 ms TTL=63
Reply from 10.0.0.3: bytes=32 time=26 ms TTL=63

Ping statistics for 10.0.0.3:
    Packets: Sent = 4, Received = 4, Lost = 0 (0% loss),
Approximate round trip times in milli-seconds:
    Minimum = 20ms, Maximum = 26ms, Average = 23ms

PS C:\Users\ThisUser\Desktop>
````
</details>


