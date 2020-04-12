# Due to the way that Windows handles minikube
# if you're using HyperV, administrator privileges are required
# This script will start/stop minikube with the elevated privileges

function PrintHelp {
    Write-Output "This script starts/stops minikube.
This script with the following parameters:
PS > ./minikube-control.ps1 [start|stop]"
    exit
}


if ( $args.Count -lt 1 ){
    PrintHelp
}

if ( $args.Count -gt 1) {
    PrintHelp
}

$action = $args[0]

if ( ($action -eq "start" -or $action -eq "stop") -eq $false ) {
    PrintHelp
}

Start-Process minikube -Wait -Verb runAs -ArgumentList $action
