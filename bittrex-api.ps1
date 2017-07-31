###############################################################################
# BITTREX API POWERSHELL IMPLEMENTATION
#------------------------------------------------------------------------------
# bittrex-api.ps1
#------------------------------------------------------------------------------
# Powershell implementation of the bittrex API
#------------------------------------------------------------------------------
# Written By: John "Brian" Clark - AKA Kewlb - The IT Jedi
# brian@clarkhouse.org
#------------------------------------------------------------------------------
# Did you find this code useful? Donation addresses below.
# 
# BTC: 1GwjRuktUcbnu7r7yNMsQAaDpp4Rd2KCE8
# ETH: 0x97a8e032d70764c2b3576aa282575a8846d428e5
# ETC: 0x6fd06b0123b6d655bf2d8062f1170235b92f1d0c
# LTC: LW8xaiBBPnxU9SJBhkTkJ4nCsWAz5K5q6e
###############################################################################


###################################################################
# CMDLET / SCRIPT INPUT PARAMETERS
###################################################################

[CmdletBinding()]
Param (
        [Parameter(Mandatory=$false)][string]$action,
        [Parameter(Mandatory=$false)][string]$market,
        [Parameter(Mandatory=$false)][string]$type,
        [Parameter(Mandatory=$false)][int]$depth,
        [Parameter(Mandatory=$false)][decimal]$quantity,
        [Parameter(Mandatory=$false)][decimal]$rate,
        [Parameter(Mandatory=$false)][string]$uuid,
        [Parameter(Mandatory=$false)][string]$currency,
        [Parameter(Mandatory=$false)][string]$address,
        [Parameter(Mandatory=$false)][string]$paymentid,
        [Parameter(Mandatory=$false)][switch]$help
    )

###################################################################
# USER CONFIGURABLE VARIABLES
###################################################################
$bt_apikey = 'YOUR-API-KEY-HERE'
$bt_apisecret = 'YOUR-API-SECRET-HERE'

###################################################################
# SCRIPT VARIABLES -- DO NOT CHANGE
###################################################################
$bt_url_base = 'https://bittrex.com/api/v1.1'
$bt_url = ""
$SCRIPT_NAME = $MyInvocation.MyCommand.Name
$EXECUTION_DIR = Split-Path $MyInvocation.MyCommand.Path

### All Available bittrex API Actions/Calls and their url directory
[hashtable]$bt_actions = @{
    "getmarkets"="/public/getmarkets";
    "getcurrencies"="/public/getcurrencies";
    "getticker"="/public/getticker";
    "getmarketsummaries"="/public/getmarketsummaries";
    "getmarketsummary"="/public/getmarketsummary";
    "getorderbook"="/public/getorderbook";
    "getmarkethistory"="/public/getmarkethistory";
    "buylimit"="/market/buylimit";
    "selllimit"="/market/selllimit";
    "marketcancel"="/market/cancel";
    "getopenorders"="/market/getopenorders";
    "getbalances"="/account/getbalances";
    "getbalance"="/account/getbalance";
    "getdepositaddress"="/account/getdepositaddress";
    "withdraw"="/account/withdraw";
    "getorder"="/account/getorder";
    "getorderhistory"="/account/getorderhistory";
    "getwithdrawalhistory"="/account/getwithdrawalhistory";
    "getdeposithistory"="/account/getdeposithistory";
}

### Used to provide help on actions
[hashtable]$bt_action_arguments = @{
    "getmarkets"="no arguments required.";
    "getcurrencies"="no arguments required.";
    "getticker"="Required Arguments: ^cymarket^cn";
    "getmarketsummaries"="no arguments required.";
    "getmarketsummary"="Required Arguments: ^cymarket^cn";
    "getorderbook"="Required Arguments: ^cymarket^cn and ^cytype^cn (^cmbuy^cn,^cmsell^cn,^cmboth^cn) | Optional: ^ccdepth^cn (^cm1^cn-^cm50^cn)";
    "getmarkethistory"="Required Arguments: ^cymarket^cn";
    "buylimit"="Required Arguments: ^cymarket^cn, ^cyquantity^cn, ^cyrate^cn";
    "selllimit"="Required Arguments: ^cymarket^cn, ^cyquantity^cn, ^cyrate^cn";
    "marketcancel"="Required Arguments: ^cyuuid^cn";
    "getopenorders"="Optional Arguments: ^ccmarket^cn";
    "getbalances"="no arguments required.";
    "getbalance"="Required Arguments: ^cycurrency^cn";
    "getdepositaddress"="Required Arguments: ^cycurrency^cn";
    "withdraw"="Required Arguments: ^cycurrency^cn, ^cyquantity^cn, ^cyaddress^cn | Optional: ^ccpaymentid^cn";
    "getorder"="Required Arguments: ^cyuuid^cn";
    "getorderhistory"="Optional Arguments: ^ccmarket^cn";
    "getwithdrawalhistory"="Optional Arguments: ^cccurrency^cn";
    "getdeposithistory"="Optional Arguments: ^cccurrency^cn";
}

##################################################################
# SCRIPT FUNCTIONS -- DO NOT CHANGE
##################################################################

### Function used to execute an API call to bittrex
function New-btQuery()
{
<#
  .SYNOPSIS
    Issues a new API call to bittrex for the requested action
  .DESCRIPTION
    Issues a new API call to bittrex for the requested action.
  .PARAMETER url
    Mandatory. String Value of the full URL for the API request. 
    **** Do not include nonce - this function will insert it ****
  .INPUTS
    [string]$url
  .OUTPUTS
    Hashtable result of the bittrex API call
  .NOTES
    Version:        1.0
    Author:         Brian Clark
    Creation Date:  07/25/2017
    Purpose/Change: Initial function development
  .EXAMPLE
    New-btQuery -url "https://bittrex.com/api/v1.1/account/getbalances?apikey=111111111"
#>
    [CmdletBinding()]
    Param ([Parameter(Mandatory=$true)][string]$url)

    ### Generate NOnce - bittrex expects 10 digits
    $epoc_start_date = ("01/01/1970" -as [DateTime])
    [int]$int_nonce = ((New-TimeSpan -Start $epoc_start_date -End ([DateTime]::UtcNow)).TotalSeconds -as [string])
    [string]$nonce = ($int_nonce -as [string])

    ### Add nonce to our URL string
    $api_url = "$($url)&nonce=$($nonce)"

    ### Encode URL and convert to raw bytes
    $utf8enc = New-Object System.Text.UTF8Encoding
    $url_bytes = $utf8enc.GetBytes($api_url)

    ### Generate SHA 512 Hash
    $sha512 = New-Object System.Security.Cryptography.HMACSHA512
    $sha512.key = [Text.Encoding]::ASCII.GetBytes($bt_apisecret)
    $sha_result = $sha512.ComputeHash($url_bytes)

    ### Convert SHA output to HEX and remove dashes
    $sha_sig = [System.BitConverter]::ToString($sha_result) -replace "-";

    ### Add SHA Signature to Header
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("apisign",$sha_sig)

    ### Make the Request
    $request = Invoke-WebRequest $api_url -Headers $headers | ConvertFrom-Json

    ### Verify bittrex returned the expected JSON Data
    if (-not $request.PSObject.Properties['success'])
    {
        Write-Host "BITTREX ERROR: Failed to get data back from the bittrex api website!" -ForegroundColor Red
        return $null
    }
    ### Verify the API Query was a Success
    if (-not $request.success -eq $True)
    {
        Write-Host "BITTREX ERROR: API Query returned an error." -ForegroundColor Red
        Write-Host "Error Message: $($request.message)" -ForegroundColor Red
        return $null
    }

    ### Return the API Query Result
    return $request.result

}

Function Write-Color
{
<#
  .SYNOPSIS
    Enables support to write multiple color text on a single line
  .DESCRIPTION
    Users color codes to enable support to write multiple color text on a single line
    ################################################
    # Write-Color Color Codes
    ################################################
    # ^cn = Normal Output Color
    # ^ck = Black
    # ^cb = Blue
    # ^cc = Cyan
    # ^ce = Gray
    # ^cg = Green
    # ^cm = Magenta
    # ^cr = Red
    # ^cw = White
    # ^cy = Yellow
    # ^cB = DarkBlue
    # ^cC = DarkCyan
    # ^cE = DarkGray
    # ^cG = DarkGreen
    # ^cM = DarkMagenta
    # ^cR = DarkRed
    # ^cY = DarkYellow [Unsupported in Powershell]
    ################################################
  .PARAMETER text
    Mandatory. Line of text to write
  .INPUTS
    [string]$text
  .OUTPUTS
    None
  .NOTES
    Version:        1.0
    Author:         Brian Clark
    Creation Date:  01/21/2017
    Purpose/Change: Initial function development
    Version:        1.1
    Author:         Brian Clark
    Creation Date:  01/23/2017
    Purpose/Change: Fix Gray / Code Format Fixes
  .EXAMPLE
    Write-Color "Hey look ^crThis is red ^cgAnd this is green!"
#>

  [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)][string]$text
    )

    ### If $text contains no color codes just write-host as normal
    if (-not $text.Contains("^c"))
    {
        Write-Host "$($text)"
        return
    }


    ### Set to true if the beginning of $text is a color code. The reason for this is that
    ### the generated array will have an empty/null value for the first element in the array
    ### if this is the case.
    ### Since we also assume that the first character of a split string is a color code we
    ### also need to know if it is, in fact, a color code or if it is a legitimate character.
    $blnStartsWithColor = $false
    if ($text.StartsWith("^c")) {
        $blnStartsWithColor = $true
    }

    ### Split the array based on our color code delimeter
    $strArray = $text -split "\^c"
    ### Loop Counter so we can generate a new empty line on the last element of the loop
    $count = 1

    ### Loop through the array
    $strArray | % {
        if ($count -eq 1 -and $blnStartsWithColor -eq $false)
        {
            Write-Host $_ -NoNewline
            $count++
        }
        elseif ($_.Length -eq 0)
        {
            $count++
        }
        else
        {

            $char = $_.Substring(0,1)
            $color = ""
            switch -CaseSensitive ($char) {
                "b" { $color = "Blue" }
                "B" { $color = "DarkBlue" }
                "c" { $color = "Cyan" }
                "C" { $color = "DarkCyan" }
                "e" { $color = "Gray" }
                "E" { $color = "DarkGray" }
                "g" { $color = "Green" }
                "G" { $color = "DarkGreen" }
                "k" { $color = "Black" }
                "m" { $color = "Magenta" }
                "M" { $color = "DarkMagenta" }
                "r" { $color = "Red" }
                "R" { $color = "DarkRed" }
                "w" { $color = "White" }
                "y" { $color = "Yellow" }
                "Y" { $color = "DarkYellow" }
            }

            ### If $color is empty write a Normal line without ForgroundColor Option
            ### else write our colored line without a new line.
            if ($color -eq "")
            {
                Write-Host $_.Substring(1) -NoNewline
            }
            else
            {
                Write-Host $_.Substring(1) -NoNewline -ForegroundColor $color
            }
            ### Last element in the array writes a blank line.
            if ($count -eq $strArray.Count)
            {
                Write-Host ""
            }
            $count++
        }
    }
}

##################################################################
##################################################################
# MAIN SCRIPT BODY
##################################################################
##################################################################

### handle the script being run without arguments or in help mode.
if (-not $action -or $help)
{
    Write-Host "`r`nbittrex-api version 1.0 (07/25/2017)"
    Write-Host "Usage: `$var = .\$($SCRIPT_NAME) -action <action-to-perform> <additional arguments>"
    Write-Host "`r`n Actions:-"
    $bt_action_arguments.Keys | % {
        Write-Color "   Action: ^cg$($_)^cn | $($bt_action_arguments[$_])"
    }
    Write-Host "`r`n"
    return
}

### Verify the requested action is a known API Call
if (-not $bt_actions.ContainsKey($action.ToLower()))
{
    Write-Host "`r`nSyntax Error: $($action) is not a known API call." -ForegroundColor Red
    Write-Host "for help type ./$($SCRIPT_NAME) -help`r`n" -ForegroundColor Yellow
    Write-Host "VALID ACTIONS: "
    $bt_actions.Keys | % { Write-Host "`t$($_)" }
    Write-Host "`r`n"
    Write-Host ""
    return
}

### Start to build the API Query URL
$bt_url = "$($bt_url_base)$($bt_actions[$action.ToLower()])?apikey=$($bt_apikey)"

### Verify the requested action has all required optional parameters included
### provide help if not all parameters are included
### build the api query url string
switch ($action) {
    ####################################################################################################################
    "getticker" {
        if (-not $market)
        {
            Write-Host "`r`nSyntax Error: You must specify the market for action getticker!" -ForegroundColor Red
            Write-Host "`r`nExample:`r`n`t `$ticker = .\$($SCRIPT_NAME) -action getticker -market BTC-ETH`r`n"
            return
        }
        $bt_url = "$($bt_url)&market=$($market)"
    }
    ####################################################################################################################
    "getmarketsummary" {
        if (-not $market)
        {
            Write-Host "`r`nSyntax Error: You must specify the market for action getmarketsummary!" -ForegroundColor Red
            Write-Host "`r`nExample:`r`n`t `$marketsummary = .\$($SCRIPT_NAME) -action getmarketsummary -market BTC-ETH`r`n"
            return
        }
        $bt_url = "$($bt_url)&market=$($market)"
    }
    ####################################################################################################################
    "getorderbook" {
        if (-not $market -or -not $type -or ($type.ToLower() -ne "buy" -and $type.ToLower() -ne "sell" -and $type.ToLower() -ne "both"))
        {
            Write-Host "`r`nSyntax Error: You must specify the market and type for action getorderbook!" -ForegroundColor Red
            Write-Host "valid types are: buy, sell, or both" -ForegroundColor Yellow
            Write-Host "optionally you can specify depth with a value of 1 to 50 - the default value is 20." -ForegroundColor Yellow
            Write-Host "`r`nExamples:`r`n`t`$orderbook = .\$($SCRIPT_NAME) -action getorderbook -market BTC-ETH -type `"both`""
            Write-Host "`t`$orderbook = .\$($SCRIPT_NAME) -action getorderbook -market BTC-ETH -type `"sell`" -depth 50`r`n"
            return
        }
        if ($depth)
        {
            if ($depth -lt 1) { $depth = 1 }
            if ($depth -gt 50) { $depth = 50 }
            $bt_url = "$($bt_url)&market=$($market)&type=$($type)&depth=$($depth)"
        }
        else
        {
            $bt_url = "$($bt_url)&market=$($market)&type=$($type)"
        }
    }
    ####################################################################################################################
    "getmarkethistory" {
        if (-not $market)
        {
            Write-Host "`r`nSyntax Error: You must specify the market for action getmarkethistory!" -ForegroundColor Red
            Write-Host "`r`nExample:`r`n`t `$markethistory = .\$($SCRIPT_NAME) -action getmarkethistory -market BTC-ETH`r`n"
            return
        }
        $bt_url = "$($bt_url)&market=$($market)"
    }
    ####################################################################################################################
    "buylimit" {
        if (-not $market -or -not $quantity -or -not $rate)
        {
            Write-Host "`r`nSyntax Error: You must specify the market, quantity, and rate for action buylimit!" -ForegroundColor Red
            Write-Host "`r`nExample:`r`n`t`$buyorder = .\$($SCRIPT_NAME) -action buylimit -market BTC-ETH -quantity 1.234 -rate 0.0567"
            return
        }
        $bt_url = "$($bt_url)&market=$($market)&quantity=$($quantity)&rate=$($rate)"
    }
    ####################################################################################################################
    "selllimit" {
        if (-not $market -or -not $quantity -or -not $rate)
        {
            Write-Host "`r`nSyntax Error: You must specify the market, quantity, and rate for action selllimit!" -ForegroundColor Red
            Write-Host "`r`nExample:`r`n`t`$sellorder = .\$($SCRIPT_NAME) -action selllimit -market BTC-ETH -quantity 1.234 -rate 0.0567"
            return
        }
        $bt_url = "$($bt_url)&market=$($market)&quantity=$($quantity)&rate=$($rate)"
    }
    ####################################################################################################################
    "marketcancel" {
        if (-not $uuid)
        {
            Write-Host "`r`nSyntax Error: You must specify the buylimit or selllimit uuid to cancel a market order!" -ForegroundColor Red
            Write-Host "`r`nExamples:`r`n`t`$marketcancel = .\$($SCRIPT_NAME) -action marketcancel -uuid `$MyOrder.UUID`r`n"
            Write-Host "`t`$marketcancel = .\$($SCRIPT_NAME) -action marketcancel -uuid `"614c34e4-8d71-11e3-94b5-425861b86ab6`"`r`n"
            return
        }
        $bt_url = "$($bt_url)&uuid=$($uuid)"
    }
    ####################################################################################################################
    "getopenorders" {
        if ($market)
        {
            $bt_url = "$($bt_url)&market=$($market)"
        }
    }
    ####################################################################################################################
    "getbalance" {
        if (-not $currency)
        {
            Write-Host "`r`nSyntax Error: You must specify the currency for action getbalance!" -ForegroundColor Red
            Write-Host "`r`nExample:`r`n`t `$btcbalance = .\$($SCRIPT_NAME) -action getbalance -currency BTC`r`n"
            return
        }
        $bt_url = "$($bt_url)&currency=$($currency)"
    }
    ####################################################################################################################
    "getdepositaddress" {
        if (-not $currency)
        {
            Write-Host "`r`nSyntax Error: You must specify the currency for action getdepositaddress!" -ForegroundColor Red
            Write-Host "`r`nExample:`r`n`t `$address = .\$($SCRIPT_NAME) -action getdepositaddress -currency BTC`r`n"
            return
        }
        $bt_url = "$($bt_url)&currency=$($currency)"
    }
    ####################################################################################################################
    "withdraw" {
        if (-not $currency -or -not $quantity -or -not $address)
        {
            Write-Host "`r`nSyntax Error: You must specify the currency, quantity, and address for action withdraw!" -ForegroundColor Red
            Write-Host " paymentid is an optional parameter used for CryptoNotes/BitShareX/Nxt optional field (memo/paymentid)" -ForegroundColor Yellow
            Write-Host "`r`nExample:`r`n`t`$withdraw = .\$($SCRIPT_NAME) -action withdraw -currency BTC -quantity 0.2501 -address `"1GwjRuktUcbnu7r7yNMsQAaDpp4Rd2KCE8`""
            return
        }
        $bt_url = "$($bt_url)&currency=$($currency)&quantity=$($quantity)&address=$($address)"
        if ($paymentid) { $bt_url = "$($bt_url)&paymentid=$($paymentid)" }
    }
    ####################################################################################################################
    "getorder" {
        if (-not $uuid)
        {
            Write-Host "`r`nSyntax Error: You must specify the order uuid to use action getorder!" -ForegroundColor Red
            Write-Host "`r`nExamples:`r`n`t`$order = .\$($SCRIPT_NAME) -action getorder -uuid `$MyOrder.UUID`r`n"
            Write-Host "`t`$order = .\$($SCRIPT_NAME) -action getorder -uuid `"614c34e4-8d71-11e3-94b5-425861b86ab6`"`r`n"
            return
        }
        $bt_url = "$($bt_url)&uuid=$($uuid)"
    }
    ####################################################################################################################
    "getwithdrawalhistory" {
        if ($currency)
        {
            $bt_url = "$($bt_url)&currency=$($currency)"
        }
    }
    ####################################################################################################################
    "getdeposithistory" {
        if ($currency)
        {
            $bt_url = "$($bt_url)&currency=$($currency)"
        }
    }
    ####################################################################################################################
}

### Make the API Query
$result = New-btQuery -url $bt_url

### return the result
return $result
