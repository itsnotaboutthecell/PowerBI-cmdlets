function Invoke-GraphAuthentication {
    [CmdletBinding()]
    param ( $authParams )

	if (!$authParams) {
		Write-Host -ForegroundColor "Yellow" "`nNo Authentication Parameters provided`n"
        break
	} else {
		Write-Host -ForegroundColor "Green" "`nAuthentication Parameters detected"
        Write-Verbose ($authParams | ConvertTo-JSON)
	}
    switch ($authParams.grant_type) {

        "client_credentials" {
            $authUri = "https://login.microsoftonline.com/$($authParams.tenantId)/oauth2";
            Write-Host "Personal Access Token (PAT) grant_type"
            
            $authBody = @{
                grant_type = "client_credentials"
                client_id = $authParams.client_id
                client_secret = $authParams.client_secret
                scope = $authParams.scope
                resource = $authParams.resource
            }
 
            Write-Host "`n----------------------------------------------------------------------------"
            Write-Host "Authentiating with Microsoft Graph API using a Personal Access Token (PAT)"
            Write-Host "https://docs.microsoft.com/en-us/azure/storage/common/storage-auth-aad-app" -ForegroundColor Gray
            Write-Host "----------------------------------------------------------------------------"

            $URI = "$authUri/token"; Write-Host "Requesting Token at $URI"
            Try {
                $authResponse = Invoke-RestMethod -Method Post -Uri $URI -Body $authBody -ErrorAction Stop
                
                ## If there is no error and a response is returned.
                Write-Host -ForeGroundColor Green "`n`nReceived Token!"
                Write-Host -ForegroundColor Green "Connected and Access Token received and will expire $($Response.expires_on)"    
                return $authResponse
            } Catch {
                return $_
            }
            return $authResponse
        }

        "device_code" {
            $authUri = "https://login.microsoftonline.com/$($authParams.tenantid)/oauth2";
            Write-Host "Device Code Authentication. Standby and wait for Device Code below."
            
            $authBody = @{
                resource = $authParams.resource
                grant_type = "device_code"
                client_id = $authParams.client_id
            }
            if ($authParams.scope) { $authBody.scope = $authParams.scope}
            
            $deviceCodeResponse = Invoke-RestMethod -Method POST -Uri "$authUri/devicecode" -Body $authBody
            Write-verbose "Requesting device code from URI: $authUri/devicecode"
            $authBody.code = $deviceCodeResponse.device_code
            Write-Host "`n$($deviceCodeResponse.message) "
            $code = ($deviceCodeResponse.message -split "code " | Select-Object -Last 1) -split " to authenticate."
            Write-Host "You can also goto https://aka.ms/devicelogin"
            Write-Host "`nDouble click this code and CTRL-V to copy: " -NoNewLine; Write-Host -ForeGroundColor cyan "$($code)"
            Set-Clipboard -Value $code
            
            Write-Host -ForeGroundColor Yellow "`nWaiting for code " -noNewLine
            $Response = $null
            $errorMessage = ""
            DO {
                Try {
                    $Response = Invoke-RestMethod -Method POST -Uri "$authUri/token" -Body $authBody -ErrorAction Stop
                    
                    ## If there is no error and a response is returned.
                    Write-Host -ForeGroundColor Green "`n`nReceived Token!"
                    Write-Host -ForegroundColor Green "Connected and Access Token received and will expire $($Response.expires_on)"    
                    return $Response
                }
                Catch {
                    $errorMessage = ($_.ErrorDetails.Message | ConvertFrom-Json)
                    Write-Host "." -noNewLine
                    Start-Sleep -Seconds 2
                    }
            } While ($errorMessage.error -eq "authorization_pending")
            if ($errorMessage) {
                Write-Host -foregroundColor red "`n`nProblem getting access token"
                Write-Host ($errorMessage | ConvertTo-JSON)
            } 
        }
        
        "refresh_token" {
            $authUrl = "https://login.windows.net/$($authParams.tenantId)/oauth2/v2.0/token"
            Write-Host "`n----------------------------------------------------------------------------"
            Write-Host "Refreshing Access Token with Microsoft Graph API using a Refresh Token"
            Write-Host "https://docs.microsoft.com/en-us/azure/storage/common/storage-auth-aad-app" -ForegroundColor Gray
            Write-Host "----------------------------------------------------------------------------"
        	
            $authResponse = Invoke-RestMethod -Method Post -Uri $authUrl -Body $authBody -ErrorAction Stop
            Write-Host "$($authResponse.length)"
        }
    }
}

Function Invoke-MSGraphQuery{
<#
.NOTES
   Name: Invoke-MSGraphQuery.ps1
   Author: Vikingur Saemundsson, Xenit AB
   Date Created: 2019-02-26
   Version History:
       2019-02-26 - Vikingur Saemundsson
#>
    [CmdletBinding(DefaultParametersetname="Default")]
    Param(
        [Parameter(Mandatory=$true,ParameterSetName='Default')]
        [Parameter(Mandatory=$true,ParameterSetName='Refresh')]
        [string]$URI,

        [Parameter(Mandatory=$false,ParameterSetName='Default')]
        [Parameter(Mandatory=$false,ParameterSetName='Refresh')]
        [string]$Body,

        [Parameter(Mandatory=$true,ParameterSetName='Default')]
        [Parameter(Mandatory=$true,ParameterSetName='Refresh')]
        [string]$token,

        [Parameter(Mandatory=$false,ParameterSetName='Default')]
        [Parameter(Mandatory=$false,ParameterSetName='Refresh')]
        [ValidateSet('GET','POST','PUT','PATCH','DELETE')]
        [string]$method = "GET",

        [Parameter(Mandatory=$false,ParameterSetName='Default')]
        [Parameter(Mandatory=$false,ParameterSetName='Refresh')]
        [switch]$recursive,

        [Parameter(Mandatory=$true,ParameterSetName='Refresh')]
        [switch]$tokenrefresh,

        [Parameter(Mandatory=$true,ParameterSetName='Refresh')]
        [pscredential]$credential,

        [Parameter(Mandatory=$true,ParameterSetName='Refresh')]
        [string]$tenantID
    )
    
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    $authHeader = @{
        'Accept'= 'application/json'
        'Content-Type'= 'application/json'
        'Authorization'= $Token
    }
    
    [array]$returnvalue = $()
    
    ## if there is body in the request, use one request vs one without any.
    Try{
        If($body){
            $Response = Invoke-RestMethod -Uri $URI –Headers $authHeader -Body $Body –Method $method -ErrorAction Stop
        }
        Else{
            $Response = Invoke-RestMethod -Uri $URI –Headers $authHeader –Method $method -ErrorAction Stop
        }
    }    ## If there are errors feed error to response.
    Catch{
        If(($Error[0].ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue).error.Message -eq 'Access token has expired.' -and $tokenrefresh){
            $token =  Get-MSGraphAuthToken -credential $credential -tenantID $TenantID
 
            $authHeader = @{
                'Content-Type'='application\json'
                'Authorization'=$Token
            }
            $returnvalue = $()
            If($body){
                $Response = Invoke-RestMethod -Uri $URI –Headers $authHeader -Body $Body –Method $method -ErrorAction Stop
            }
            Else{
                $Response = Invoke-RestMethod -Uri $uri –Headers $authHeader –Method $method
            }
        }
        Else{
            Throw $_
        }
    }
 
    $returnvalue += $Response
    If(-not $recursive -and $Response.'@odata.nextLink'){
        Write-Warning "Query contains more data, use recursive to get all!"
        Start-Sleep 1
    }
    ElseIf($recursive){
        If($PSCmdlet.ParameterSetName -eq 'default'){
            If($body){
                $returnvalue += Invoke-MSGraphQuery -URI $Response.'@odata.nextLink' -token $token -body $body -method $method -recursive -ErrorAction SilentlyContinue
            }
            Else{
                $returnvalue += Invoke-MSGraphQuery -URI $Response.'@odata.nextLink' -token $token -method $method -recursive -ErrorAction SilentlyContinue
            }
        }
        Else{
            If($body){
                $returnvalue += Invoke-MSGraphQuery -URI $Response.'@odata.nextLink' -token $token -body $body -method $method -recursive -tokenrefresh -credential $credential -tenantID $TenantID -ErrorAction SilentlyContinue
            }
            Else{
                $returnvalue += Invoke-MSGraphQuery -URI $Response.'@odata.nextLink' -token $token -method $method -recursive -tokenrefresh -credential $credential -tenantID $TenantID -ErrorAction SilentlyContinue
            }
        }
    }
    Return $returnvalue
}

Function Get-MSGraphAuthToken{
<#
.NOTES
   Name: Get-MSGraphAuthToken.ps1
   Author: Vikingur Saemundsson, Xenit AB
   Date Created: 2019-02-26
   Version History:
       2019-02-26 - Vikingur Saemundsson
#>
[cmdletbinding()]
Param(
    [parameter(Mandatory=$true)]
    [pscredential]$credential,
    [parameter(Mandatory=$true)]
    [string]$tenantID
    )
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    #Get token
    $AuthUri = "https://login.microsoftonline.com/$TenantID/oauth2/token"
    $Resource = 'graph.microsoft.com'
    $AuthBody = "grant_type=client_credentials&client_id=$($credential.UserName)&client_secret=$($credential.GetNetworkCredential().Password)&resource=https%3A%2F%2F$Resource%2F"
    
    $Response = Invoke-RestMethod -Method Post -Uri $AuthUri -Body $AuthBody
    If($Response.access_token){
        return $Response.access_token
    }
    Else{
        Throw "Authentication failed"
    }
}