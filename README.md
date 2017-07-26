# powershell-bittrex-api  
Powershell Wrapper for the Bittrex Crypto Currency Exchange API  
Written By: Brian Clark - AKA Kewlb - The IT Jedi - brian@clarkhouse.org  
  
# Donations are always welcome:  
BTC: 1GwjRuktUcbnu7r7yNMsQAaDpp4Rd2KCE8  
ETH: 0x97a8e032d70764c2b3576aa282575a8846d428e5  
ETC: 0x6fd06b0123b6d655bf2d8062f1170235b92f1d0c  
LTC: LW8xaiBBPnxU9SJBhkTkJ4nCsWAz5K5q6e  
  
  
Bittrex API Documentation: https://bittrex.com/Home/Api  
  
# Action Strings  
getmarkets - Used to get the open and available trading markets at Bittrex along with other meta data.  
getcurrencies - Used to get all supported currencies at Bittrex along with other meta data.  
getticker - Used to get the current tick values for a market.  
getmarketsummaries - Used to get the last 24 hour summary of all active exchanges  
getmarketsummary - Used to get the last 24 hour summary of all active exchanges 
getorderbook - Used to get retrieve the orderbook for a given market  
getmarkethistory - Used to retrieve the latest trades that have occured for a specific market.  
buylimit - Used to place a buy order in a specific market.  
selllimit - Used to place a sell order in a specific market.  
marketcancel - Used to cancel a buy or sell order.  
getopenorders - Get all orders that you currently have opened. A specific market can be requested  
getbalances - Used to retrieve all balances from your account  
getbalance - Used to retrieve the balance from your account for a specific currency.  
getdepositaddress - Used to retrieve or generate an address for a specific currency.  
withdraw - Used to withdraw funds from your account. note: please account for txfee.  
getorder - Used to retrieve a single order by uuid.  
getorderhistory - Used to retrieve your order history.  
getwithdrawalhistory - Used to retrieve your withdrawal history.  
getdeposithistory - Used to retrieve your deposit history.  
  
# SETUP  
In the User Configurable Variables section of the script edit the below 2 lines of code putting in your API Key and Secret Key  
$bt_apikey = 'YOUR-API-KEY-HERE'  
$bt_apisecret = 'YOUR-API-SECRET-HERE'  
  
# USE  
Call the script with one of the required action strings listed above as well as the required input for that action.  
To get help run the script without any arguments or with the -help switch  
If you fail to provide the correct input for an action additional help will be provided to you.  
  
# EXAMPLE #1 - PULL CURRENT MARKET DATA  
$market = .\bittrex-api.ps1 -action getmarketsummaries  
  
# EXAMPLE #2 - USE MARKET DATA WE JUST PULLED TO SEE WHO HAS MORE BUY ORDERS OUT THAN SELL ORDERS  
$market | ? {$_.OpenBuyOrders -gt $_.OpenSellOrders}  
  
# EXAMPLE #3 - USE MARKET DATA WE JUST PULLED TO FIND THE CURRENT TOP 5 PERFORMING CURRENCIES  
$market | % {  
    [decimal]$change_amount = $_.Last - $_.PrevDay  
    [decimal]$change_percent = "{0:N4}" -f (($change_amount / $_.PrevDay) * 100)  
    $_ | Add-Member -NotePropertyName ChangedValue -NotePropertyValue $change_amount  
    $_ | Add-Member -NotePropertyName ChangePercent -NotePropertyValue $change_percent  
}  
$market | Sort  @{e={$_.ChangePercent -as [decimal]}} -Descending | Select -First 5  
  
# EXAMPLE #4 - GET ACCOUNT BALANCES / BTC VALUE OF HOLDINGS / USD VALUE OF HOLDINGS  
[decimal]$total_btc_value = 0.0  
[decimal]$btc_usd_value = 0.0  
$balances = .\bittrex-api.ps1 -action getbalances  
$balances | % {  
    if ($_.Currency -ne 'BTC')  
    {  
        $ticker = .\bittrex-api.ps1 -action getticker -market "BTC-$($_.Currency)"  
        $_ | Add-Member -NotePropertyName LastTradePrice -NotePropertyValue $ticker.Last  
        $value = "{0:N8}" -f ($_.Balance * $_.LastTradePrice)  
        $_ | Add-Member -NotePropertyName ValueBTC -NotePropertyValue $value  
        $total_btc_value += $value  
    }  
    else  
    {  
        $ticker = .\bittrex-api.ps1 -action getticker -market "USDT-BTC"  
        $_ | Add-Member -NotePropertyName LastTradePrice -NotePropertyValue $ticker.Last  
        $btc_usd_value = $_.LastTradePrice  
        $value = ($_.Balance * $_.LastTradePrice)  
        $_ | Add-Member -NotePropertyName ValueUSD -NotePropertyValue $value  
        $total_btc_value += $_.Balance  
    }  
}  
$total_btc_usd_value = "{0:N2}" -f ($total_btc_value * $btc_usd_value)  
Write-Host "Portfolio is worth $($total_btc_value) BTC / $($total_btc_usd_value) USD"  
  
