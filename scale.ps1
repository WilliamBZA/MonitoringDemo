
Write-Host "Scaling out TheMessageProcessor endpoint"
Start-Process ".\Solution\binaries\TheMessageProcessor\net461\TheMessageProcessor.exe"  -ArgumentList "instance-1" -WorkingDirectory ".\Solution\binaries\TheMessageProcessor\net461\"
Start-Sleep -Seconds 20
Start-Process ".\Solution\binaries\TheMessageProcessor\net461\TheMessageProcessor.exe"  -ArgumentList "instance-2" -WorkingDirectory ".\Solution\binaries\TheMessageProcessor\net461\"
Start-Sleep -Seconds 20
Start-Process ".\Solution\binaries\TheMessageProcessor\net461\TheMessageProcessor.exe"  -ArgumentList "instance-3" -WorkingDirectory ".\Solution\binaries\TheMessageProcessor\net461\"
