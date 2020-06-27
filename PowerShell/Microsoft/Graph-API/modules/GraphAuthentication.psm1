function Invoke-GraphAuthentication {
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
             $authUri = "https://login.microsoftonline.com/$($authParams.tenant)/oauth2";
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

            $authResponse = Invoke-RestMethod -Method Post -Uri "$authUri/token" -Body $authBody -ErrorAction Stop
            return $authResponse
        }

        "device_code" {
            $authUri = "https://login.microsoftonline.com/$($authParams.tenant)/oauth2";
            Write-Host "Device Code Workflow"
            
            $authBody = @{
                resource = $authParams.resource
                grant_type = "device_code"
                client_id = $authParams.client_id
            }
            if ($authParams.scope) { $authBody.scope = $authParams.scope}
            
            $deviceCodeResponse = Invoke-RestMethod -Method POST -Uri "$authUri/devicecode" -Body $authBody
            $authBody.code = $deviceCodeResponse.device_code
            Write-Host "`n$($deviceCodeResponse.message) "
            $code = ($deviceCodeResponse.message -split "code " | Select-Object -Last 1) -split " to authenticate."
            Write-Host "`nDouble click this code and CTRL-V to copy: " -NoNewLine; Write-Host -ForeGroundColor cyan "$($code)"
            Set-Clipboard -Value $code
            
            Write-Host ($authBody | ConvertTo-JSON)
            
            Write-Host -ForeGroundColor Yellow "`nWaiting for code"
            While (!$tokenResponse) {
                Try {
                    $tokenResponse = Invoke-RestMethod -Method POST -Uri "$authUri/token" -Body $authBody -ErrorAction Ignore
                    Write-Host -ForeGroundColor Green "`nReceived Token!"
                    Write-Host -ForegroundColor Green "Connected and Access Token received and will expire $($tokenResponse.expires_on)"
                    return $tokenResponse
                } Catch {
                }
            }   
        }
        
        "refresh_token" {
            $authUrl = "https://login.windows.net/$($authParams.tenantId)/oauth2/v2.0/token"
            Write-Host "`n----------------------------------------------------------------------------"
            Write-Host "Refreshing Access Token with Microsoft Graph API using a Refresh Token"
            Write-Host "https://docs.microsoft.com/en-us/azure/storage/common/storage-auth-aad-app" -ForegroundColor Gray
            Write-Host "----------------------------------------------------------------------------"
        	
            $authResponse = Invoke-RestMethod -Method Post -Uri $authUrl -Body $authBody -ErrorAction Stop
            if ($authResponse.expires_in) {
                Write-Host -foregroundColor green "`nSuccessfully refreshed token."
                return $authResponse
            }
        }
    }
}