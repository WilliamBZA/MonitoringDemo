Set-Location $PSScriptRoot

function Invoke-SQL {
  param(
      [string] $connectionString,
      [string] $file,
      [string] $v
    )

  $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
  $command = new-object system.data.sqlclient.sqlcommand($sqlCommand, $connection)
  
  $connection.Open()
  
  $queryTemplate = [IO.File]::ReadAllText($file);
  $command.CommandText = $queryTemplate.Replace("{arg}", $v)
  $command.ExecuteNonQuery();

  $connection.Close()
}

function Add-EndpointQueues {
  param(
      [string] $connectionString,
      [string] $endpointName
  )

  Invoke-SQL -connectionString $connectionString -file "$($PSScriptRoot)\support\CreateQueue.sql" -v "$endpointName" | Out-Null
  Invoke-SQL -connectionString $connectionString -file "$($PSScriptRoot)\support\CreateQueue.sql" -v "$endpointName.staging" | Out-Null
  Invoke-SQL -connectionString $connectionString -file "$($PSScriptRoot)\support\CreateQueue.sql" -v "$endpointName.timeouts" | Out-Null
  Invoke-SQL -connectionString $connectionString -file "$($PSScriptRoot)\support\CreateQueue.sql" -v "$endpointName.timeoutsdispatcher" | Out-Null
  Invoke-SQL -connectionString $connectionString -file "$($PSScriptRoot)\support\CreateQueue.sql" -v "$endpointName.retries" | Out-Null
}

function Add-Queue {
  param(
      [string] $connectionString,
      [string] $queueName
  )

  Invoke-SQL -connectionString $connectionString -file "$($PSScriptRoot)\support\CreateQueue.sql" -v "$queueName" | Out-Null
}

function Write-Exception 
{
  param(
    [System.Management.Automation.ErrorRecord]$error
  )

  $formatstring = "{0} : {1}`n{2}`n" +
  "    + CategoryInfo          : {3}`n"
  "    + FullyQualifiedErrorId : {4}`n"

  $fields = $error.InvocationInfo.MyCommand.Name,
  $error.ErrorDetails.Message,
  $error.InvocationInfo.PositionMessage,
  $error.CategoryInfo.ToString(),
  $error.FullyQualifiedErrorId

  Write-Host -Foreground Red -Background Black ($formatstring -f $fields)
}

Function Update-ConnectionStrings {
  param (
    [string]$ConfigFile,
    [string]$ConnectionString
  )

  $xml = [xml](Get-Content $ConfigFile)
  $xml.SelectNodes("//connectionStrings/add") | % {
    $_."connectionString" = $ConnectionString
  }

  $xml.Save($ConfigFile)
}

try {
  Write-Host -ForegroundColor Yellow "Checking prerequisites"

  Write-Host "Checking LocalDB"
  if((Get-Command "sqllocaldb.exe" -ErrorAction SilentlyContinue) -eq $null){

    Write-Host "LocalDB is not installed" -ForegroundColor Red
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No",""
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($no,$yes)

    if($Host.UI.PromptForChoice("","Do you want to download the SQL Express 2016 Web Launcher from https://go.microsoft.com/fwlink/?LinkID=799012 ?",$choices,0) -eq 0) 
    { 
      Write-Host "Please see README.md for download details." 
      Write-Host "Press ENTER to exit..."
      Read-Host
      exit
    }

    Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?LinkID=799012" -OutFile SQLServer2016-SSEI-Expr.exe
    
    if($Host.UI.PromptForChoice("","Do you want to run the downloaded launcher?",$choices,0) -eq 0) 
    { 
      Write-Host "Please see README.md for LocalDB installation details." 
      Write-Host "Press ENTER to exit..."
      Read-Host
      exit
    }

    Start-Process -FilePath SQLServer2016-SSEI-Expr.exe

    Write-Host "Please go to the Web Launcher, select *Download Media*, select *LocalDB (44MB)*, then download, and run the `SqlLocalDB.msi` afterwards and restart this script" 
    Write-Host "Press ENTER to exit..."
    Read-Host
    exit
  }

  Write-Host "Checking if port for ServiceControl - 33533 is available"
  $scPortListeners = Get-NetTCPConnection -State Listen | Where-Object {$_.LocalPort -eq "33533"}
  if($scPortListeners){
    Write-Host "Default port for SC - 33533 is being used at the moment. It might be another SC instance running on this machine."
    throw "Cannot install ServiceControl. Port 33533 is taken."
  }

  Write-Host "Checking if port for SC Monitoring - 33833 is available"
  $scMonitoringPortListeners = Get-NetTCPConnection -State Listen | Where-Object {$_.LocalPort -eq "33833"}
  if($scMonitoringPortListeners){
    Write-Host "Default port for SC Monitoring - 33833 is being used at the moment. It might be another SC Monitoring instance running on this machine."
    throw "Cannot install SC Monitoring. Port 33833 is taken."
  }

  Write-Host "Checking if port for ServicePulse - 8051 is available"
  $spPortListeners = Get-NetTCPConnection -State Listen | Where-Object {$_.LocalPort -eq "8051"}
  if($spPortListeners){
    Write-Host "Default port for ServicePulse - 8051 is being used at the moment. It might be another Service Pulse running on this machine."
    throw "Cannot install Service Pulse. Port 8051 is taken."
  }

  Write-Host -ForegroundColor Yellow "Starting demo"

  Write-Host "Creating SQL Instance"
  sqllocaldb create particular-monitoring
  Write-Host "Starting SQL Instance"
  sqllocaldb start particular-monitoring

  Write-Host "Dropping and creating database"
  Invoke-SQL -connectionString "Server=(localDB)\particular-monitoring;Integrated Security=SSPI;" -file "$($PSScriptRoot)\support\CreateCatalogInLocalDB.sql" -v $PSScriptRoot | Out-Null

  $connectionString = "Server=(localDB)\particular-monitoring;Database=ParticularMonitoringDemo;Integrated Security=SSPI;"

  Write-Host "Creating shared queues"    
  Add-Queue -connectionString $connectionString -queueName "audit"
  Add-Queue -connectionString $connectionString -queueName "error"

  Write-Host "Creating ServiceControl instance queues"
  Add-EndpointQueues -connectionString $connectionString -endpointName "Particular.ServiceControl"
  Add-Queue -connectionString $connectionString -queueName "Particular.ServiceControl.$env:computername"
  
  Write-Host "Updating connection strings"
  
  Update-ConnectionStrings -ConnectionString $connectionString -ConfigFile "$($PSScriptRoot)\Platform\servicecontrol\monitoring-instance\ServiceControl.Monitoring.exe.config"
  Update-ConnectionStrings -ConnectionString $connectionString -ConfigFile "$($PSScriptRoot)\Platform\servicecontrol\servicecontrol-instance\bin\ServiceControl.exe.config"
  
  Update-ConnectionStrings -ConnectionString $connectionString -ConfigFile "$($PSScriptRoot)\Solution\binaries\ParkEntrance\net461\ParkEntrance.exe.config"
  Update-ConnectionStrings -ConnectionString $connectionString -ConfigFile "$($PSScriptRoot)\Solution\binaries\TheMessageProcessor\net461\TheMessageProcessor.exe.config"
  Update-ConnectionStrings -ConnectionString $connectionString -ConfigFile "$($PSScriptRoot)\Solution\binaries\BusinessLogicBumperCars\net461\BusinessLogicBumperCars.exe.config"
  Update-ConnectionStrings -ConnectionString $connectionString -ConfigFile "$($PSScriptRoot)\Solution\binaries\CriticalSplash\net461\CriticalSplash.exe.config"
  Update-ConnectionStrings -ConnectionString $connectionString -ConfigFile "$($PSScriptRoot)\Solution\binaries\TheAutomator\net461\TheAutomator.exe.config"
  Update-ConnectionStrings -ConnectionString $connectionString -ConfigFile "$($PSScriptRoot)\Solution\binaries\ThePubSub\net461\ThePubSub.exe.config"
  Update-ConnectionStrings -ConnectionString $connectionString -ConfigFile "$($PSScriptRoot)\Solution\binaries\SeriLogRide\net461\SeriLogRide.exe.config"
  Update-ConnectionStrings -ConnectionString $connectionString -ConfigFile "$($PSScriptRoot)\Solution\binaries\CodeFirstCaverns\net461\CodeFirstCaverns.exe.config"

  Write-Host "Starting ServiceControl instance"
  $sc = Start-Process ".\Platform\servicecontrol\servicecontrol-instance\bin\ServiceControl.exe" -WorkingDirectory ".\Platform\servicecontrol\servicecontrol-instance\bin" -Verb runAs -PassThru -WindowStyle Minimized

  Write-Host "Creating Monitoring instance queues"
  Add-EndpointQueues -connectionString $connectionString -endpointName "Particular.Monitoring"

  Write-Host "Starting Monitoring instance"
  $mon = Start-Process ".\Platform\servicecontrol\monitoring-instance\ServiceControl.Monitoring.exe" -WorkingDirectory ".\Platform\servicecontrol\monitoring-instance" -Verb runAs -PassThru -WindowStyle Minimized

  Write-Host "Creating ParkEntrance queues"
  Add-EndpointQueues -connectionString $connectionString -endpointName "ParkEntrance"

  Write-Host "Creating TheMessageProcessor queues"
  Add-EndpointQueues -connectionString $connectionString -endpointName "TheMessageProcessor"

  Write-Host "Creating BusinessLogicBumperCars queues"
  Add-EndpointQueues -connectionString $connectionString -endpointName "BusinessLogicBumperCars"

  Write-Host "Creating CriticalSplash queues"
  Add-EndpointQueues -connectionString $connectionString -endpointName "CriticalSplash"

  Write-Host "Creating TheAutomator queues"
  Add-EndpointQueues -connectionString $connectionString -endpointName "TheAutomator"

  Write-Host "Creating ThePubSub queues"
  Add-EndpointQueues -connectionString $connectionString -endpointName "ThePubSub"

  Write-Host "Creating SeriLogRide queues"
  Add-EndpointQueues -connectionString $connectionString -endpointName "SeriLogRide"

  Write-Host "Creating CodeFirstCaverns queues"
  Add-EndpointQueues -connectionString $connectionString -endpointName "CodeFirstCaverns"

  Write-Host "Starting Demo Solution"
  $businessLogicBumperCars = Start-Process ".\Solution\binaries\BusinessLogicBumperCars\net461\BusinessLogicBumperCars.exe" -WorkingDirectory ".\Solution\binaries\BusinessLogicBumperCars\net461\" -PassThru -WindowStyle Minimized
  $criticalSplash = Start-Process ".\Solution\binaries\CriticalSplash\net461\CriticalSplash.exe" -WorkingDirectory ".\Solution\binaries\CriticalSplash\net461\" -PassThru -WindowStyle Minimized
  $theAutomator = Start-Process ".\Solution\binaries\TheAutomator\net461\TheAutomator.exe" -WorkingDirectory ".\Solution\binaries\TheAutomator\net461\" -PassThru -WindowStyle Minimized
  $thePubSub = Start-Process ".\Solution\binaries\ThePubSub\net461\ThePubSub.exe" -WorkingDirectory ".\Solution\binaries\ThePubSub\net461\" -PassThru -WindowStyle Minimized
  $seriLogRide = Start-Process ".\Solution\binaries\SeriLogRide\net461\SeriLogRide.exe" -WorkingDirectory ".\Solution\binaries\SeriLogRide\net461\" -PassThru -WindowStyle Minimized
  $theMessageProcessor = Start-Process ".\Solution\binaries\TheMessageProcessor\net461\TheMessageProcessor.exe" -WorkingDirectory ".\Solution\binaries\TheMessageProcessor\net461\" -PassThru -WindowStyle Minimized
  $codeFirstCaverns = Start-Process ".\Solution\binaries\CodeFirstCaverns\net461\CodeFirstCaverns.exe" -WorkingDirectory ".\Solution\binaries\CodeFirstCaverns\net461\" -PassThru -WindowStyle Minimized
  $parkEntrance = Start-Process ".\Solution\binaries\ParkEntrance\net461\ParkEntrance.exe" -WorkingDirectory ".\Solution\binaries\ParkEntrance\net461\" -PassThru -WindowStyle Minimized
      
  Write-Host -ForegroundColor Yellow "Once ServiceControl has finished starting a browser window will pop up showing the ServicePulse monitoring tab"

  $status = -1
  do {
    Write-Host -NoNewline '.'
    Start-Sleep -s 1
    try {
      $status = (Invoke-WebRequest http://localhost:33533/api -UseBasicParsing).StatusCode
    } catch {
      $status = $_.Exception.Response.StatusCode
    }
  } while ( $status -ne 200 )

  Write-Host
  Write-Host "ServiceControl has started"

  Write-Host "Starting ServicePulse"
  $pulse = (Start-Process ".\Platform\servicepulse\ServicePulse.Host.exe" -ArgumentList "--url=`"http://localhost:8051`"" -WorkingDirectory ".\Platform\servicepulse" -Verb runAs -PassThru -WindowStyle Minimized)

  Write-Host -ForegroundColor Yellow "Press ENTER to shutdown demo"
  Read-Host
  Write-Host -ForegroundColor Yellow "Shutting down"

} catch {
  Write-Error -Message "Error starting setting up demo."
  Write-Exception $_
} finally { 

  if( $pulse ) { 
    Write-Host "Shutting down ServicePulse"
    Stop-Process -InputObject $pulse 
  }

  if( $businessLogicBumperCars ) { 
    Write-Host "Shutting down BusinessLogicBumperCars endpoint"
    Stop-Process -InputObject $businessLogicBumperCars 
  }

  if( $criticalSplash ) { 
    Write-Host "Shutting down CriticalSplash endpoint"
    Stop-Process -InputObject $criticalSplash 
  }

  if( $theAutomator ) { 
    Write-Host "Shutting down TheAutomator endpoint"
    Stop-Process -InputObject $theAutomator 
  }

  if( $thePubSub ) { 
    Write-Host "Shutting down ThePubSub endpoint"
    Stop-Process -InputObject $thePubSub 
  }

  if( $seriLogRide ) { 
    Write-Host "Shutting down SeriLogRide endpoint"
    Stop-Process -InputObject $seriLogRide 
  }
  
  if( $codeFirstCaverns ) { 
    Write-Host "Shutting down CodeFirstCaverns endpoint"
    Stop-Process -InputObject $codeFirstCaverns 
  }

  if( $theMessageProcessor ) {
    Write-Host "Shutting down TheMessageProcessor endpoint"
    Stop-Process -InputObject $theMessageProcessor 
  }
  
  if( $parkEntrance ) {
    Write-Host "Shutting down ParkEntrance endpoint"
    Stop-Process -InputObject $parkEntrance
  }

  if( $mon ) { 
    Write-Host "Shutting down Monitoring instance"
    Stop-Process -InputObject $mon 
  }

  if( $sc ) { 
    Write-Host "Shutting down ServiceControl instance"
    Stop-Process -InputObject $sc
  }

  Write-Host "Stopping SQL Instance"
  sqllocaldb stop particular-monitoring

  Write-Host "Deleting SQL Instance"
  sqllocaldb delete particular-monitoring

  Write-Host "Removing Database Files"
  Remove-Item .\transport\ParticularMonitoringDemo.mdf
  Remove-Item .\transport\ParticularMonitoringDemo_log.ldf
}

Write-Host -ForegroundColor Yellow "Done, press ENTER"
Read-Host
