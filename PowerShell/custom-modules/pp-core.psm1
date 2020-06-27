function Get-HashOfString {
    param (
        $string
    )
    
    $stringAsStream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.StreamWriter]::new($stringAsStream)
    $writer.write($string)
    $writer.Flush()
    $stringAsStream.Position = 0
    $hash = Get-FileHash -InputStream $stringAsStream | Select-Object Hash
    return $hash
}

function Get-MasterPassword {
    param (
        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=2)]
        $masterPassword        
    )
    ############################ Get Master Key ################################
    # Get a master password used to encrypt and decrypt Key
    if (!$masterPassword) {
        write-host -Foreground cyan "`nPlease enter a master password that will be used to encrypt/decrypt this credential";
        $masterPassword = Read-Host -AsSecureString
        $Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList 'user', $MasterPassword
    }
    ############################################################################

    return $Credentials
}

function Get-EncryptedStringUsingMasterPassword {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)]
        [string]$string,
        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=1)]
        $Credentials 
    )
    
        if(!$Credentials) {
            $Credentials = Get-MasterPassword
        }
        
        ################ Generate Salted Key using Master Key #########################
        # Generate a random secure Salt to be used for all objects in $credentialArray
        $SaltBytes = New-Object byte[] 32
        [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($SaltBytes)
        # This takes the master password and salt it
        # Rfc2898DeriveBytes takes a password, a salt, and an iteration count, and then generates keys through calls to the GetBytes method.
        $Rfc2898Deriver = New-Object System.Security.Cryptography.Rfc2898DeriveBytes -ArgumentList $Credentials.GetNetworkCredential().Password, $SaltBytes
        $KeyBytes = $Rfc2898Deriver.GetBytes(32)
        ##############################################################################
        Write-verbose "KeyBytes: $KeyBytes"
        $hash = (Get-HashOfString -string $Rfc2898Deriver).hash
        write-verbose "Hash (SHA256) of this string is: $hash"

        ###Use salted Master Password Key to encrypted all credential objects in credential array ####
        write-verbose "Encrypting - $string "
        $secureString = ConvertTo-SecureString -String $string -AsPlainText -Force
        # This commands uses Advanced Encryption Standard (AES) algorith
        # It will convert the secure string stored in the $SecureKeyString variable to an encrypted standard string using this 256-bit salt key.
        # The resulting encrypted standard string is stored in the $StandardString variable.
        write-verbose "Encrypting SecureString from previous step $($secureString | ConvertFrom-SecureString)"
        $encryptedStringWithKey = $secureString | ConvertFrom-SecureString -key $KeyBytes
        write-verbose "Encrypted string even further using Master Password that has been salted with 256-bit key: $encryptedStringWithKey"
        
        return @{
            encryptedString = $encryptedStringWithKey
            saltBytes = $SaltBytes
            hash = $hash
        }
}

function Get-DecryptedStringUsingMasterPassword {
    [CmdletBinding()]
    param (
        $encryptedString, $saltBytes, $hash, $Credentials
    )
    
        if(!$Credentials) {
            $Credentials = Get-MasterPassword
        }

        ############## Take Salt and Master Password provided to generate key used for decrypting credentials #######################
        $Rfc2898Deriver = New-Object System.Security.Cryptography.Rfc2898DeriveBytes -ArgumentList $Credentials.GetNetworkCredential().Password, $saltBytes
        $KeyBytes  = $Rfc2898Deriver.GetBytes(32)
        write-verbose "Using salt master key: $saltBytes"
        write-verbose "KeyBytes: $KeyBytes"
        $hash = (Get-HashOfString -string $Rfc2898Deriver).hash
        write-verbose "Hash (SHA256) of this string is: $hash"

        # This commands will decrypt the encrypted stored credential using the Salt with provided Master password from user
        write-verbose "Decrypting salted encrypted string $encryptedString"
        $secureString = ConvertTo-SecureString $encryptedString -Key $KeyBytes

        # Then we will take that Secure String from the last step and convert it back to plain text
        write-verbose "Decrypting - $secureString"
        $decryptedString = ($secureString | ConvertFrom-SecureString -AsPlainText)

        Write-verbose "decrypted String $decryptedString"
        return $decryptedString
}

function Invoke-CheckCredentials {
    param (
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)]
        [string]$credentialPath,

        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=1)]
        [hashtable]$credentialArray
    )

    ############## Create folder if doesn't exist #####################
    $credentialDirectory = (Split-Path -Path $credentialPath)
    ## Create folder if folder does not exist
    if(!(Test-path $credentialDirectory) ) {
        Write-Host "$credentialDirectory did not exist."
        New-Item -ItemType Directory -Force -Path $credentialDirectory
        Write-Host -foregroundcolor yellow "`nFolder did not existed. Creating it."
    } else {
        Write-Host -foregroundColor Green "`nFolder Exists in $credentialDirectory"
    }
    
    $storedCredentialExists = (Test-Path $credentialPath)
    ################ Check for stored credentials provided in credential Path ##############
    Write-Verbose "Grabbing credentials from $credentialPath"
    if ($storedCredentialExists) {
        $credentialXML = Import-Clixml $credentialPath -ErrorAction Stop
        write-host -foregroundColor green "Credentials located with $($credentialXML.count) objects"

        ################# Compares to see if provided credentials already exists in local file ##################
        Write-Verbose "`nComparing credentials provided with local credentials to see if objects already exists..."
        $objectCompare = @{}; 
        $objectCompare.exist = @{}; 
        $objectCompare.notExist = @{};
        if ($credentialXML) {
            ForEach ($key in $credentialArray.keys) {
                if ( $($credentialXML.$key) ) {
                    $objectCompare.exist.$key = $credentialXML.$key
                    Write-Verbose "$key exists"
                } else {
                    Write-Verbose "$key does not exist in file."
                    $objectCompare.notExist.$key = $credentialXML.$key
                }
            }
        return $objectCompare
        } else {
            Write-Verbose "No credential array provided to compare"
        return $null
        }
        
    } 
    ## If there is no stored credentials then skip local file check.
    else {
        write-host -foregroundColor red "`nNo Credential file located at '$credentialPath'"
        return "No stored credentials"
    }
    ########################################################################################

}

function New-StoreCredentials {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)]
        [string]$credentialPath,

        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=1)]
        [hashtable]$credentialArray
    )
    Write-Verbose "Started New-StoreCredential function"
    
    if (!$credentialArray) {
        $credentials = Get-StoredCredentials -credentialPath $credentialPath
        return $credentials
    }
    
    #Get masterpassword
    $Credentials = Get-MasterPassword
    
    $checkCredentials = Invoke-CheckCredentials -credentialPath $credentialPath -credentialArray $credentialArray
    
    $encryptedCredentialArray = @{}
    ForEach ($key in $credentialArray.keys) {
        
        # Encrypt string
        $encryptedString = Get-EncryptedStringUsingMasterPassword -string $credentialArray.$key -Credentials $Credentials
        
        # Store encrypted string into new encryptedCredentialArray
        $encryptedCredentialArray.$key = @{}
        $encryptedCredentialArray.$key = $encryptedString
    }
    Write-verbose ($encryptedCredentialArray | ConvertTo-JSON)
    
    ###############################################################################################
    # Storing credentials
    Write-verbose "Storing credentials in credential path:$credentialPath"
 
    ### checks to see if credential already exist and new credentials are provided
    if ( ($checkCredentials -ne "No stored credentials") -and ($encryptedCredentialArray) ) {
    
        ###############  Question Menu and prompt user for answer  #############################
        $title    = "Credential file already detected in $credentialPath`n"
        $question = "Do you want to add missing objects, replace file, or skip?"
        $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
        $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Add'))
        $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Replace'))
        $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Skip'))
    
        ############## Prompt User for answer
        $decision = $Host.UI.PromptForChoice($title, $question, $choices, 2)
        if ($decision -eq 0) {
            write-host -ForegroundColor Green "`nAdding missing items"
            Write-host $checkCredentials.notExist
            $ExportedCreds = $encryptedCredentialArray | Export-CliXml $credentialPath -Force              
        } 
        elseif ($decision -eq 1) {
            write-host -ForegroundColor Green "`nReplacing file"
            $encryptedCredentialArray | Export-CliXml $credentialPath -Force            
        } 
        else {
            write-host -ForegroundColor Yellow "`nCancelled, file won't be replaced. Exiting...."
        }
    } else {    ### If there are no credentials detected stores the encrypted credentials created
        Write-Host "Credentials provided have been stored in $credentialPath"
        $credentialXML = $encryptedCredentialArray
        $credentialXML | Export-CliXml $credentialPath -Force
        
    }
    return $credentialArray
}

function Get-StoredCredentials {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)]
        [string]$credentialPath
    )

    ## Get master password
    $Credentials = Get-MasterPassword

    Write-Verbose "Importing credentials from $credentialPath"
    $credentialArray = Import-Clixml $credentialPath -ErrorAction Stop
    
    $decryptedCredentialArray = New-Object -TypeName psobject
    ForEach ($key in $credentialArray.keys) {  

        $decryptedString = Get-DecryptedStringUsingMasterPassword -encryptedString $credentialArray.$key.encryptedString -saltBytes $credentialArray.$key.saltBytes -Credentials $credentials
        
        # Store encrypted string into new a decrypted credential array.
        $decryptedCredentialArray | Add-Member -MemberType NoteProperty -Name $key -Value $decryptedString

        write-verbose "Final decrypted Key String for $key/$decryptedString"
    }
    ###############################################################################################

    return $decryptedCredentialArray
}