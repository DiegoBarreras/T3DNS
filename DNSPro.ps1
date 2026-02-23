param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$args
)

. "$PSScriptRoot\funciones.ps1"

$script:mask = $null
$script:claseIP = $null

if ($args.Count -eq 0) {
    Write-Host "`n"
    Write-Host "---------------------------------------------"
    Write-Host "---------- MENU SCRIPT DNS SERVER ----------"
    Write-Host "---------------------------------------------`n"
    Write-Host "Para verificar la instalacion de los paquetes:"
    Write-Host ".\DNSPro.ps1 --verificarinst`n"
    Write-Host "Para re/instalar los paquetes:"
    Write-Host ".\DNSPro.ps1 --instalar`n"
    Write-Host "Para verificar la IP:"
    Write-Host ".\DNSPro.ps1 --verificarip`n"
    Write-Host "Para asignar una IP estatica:"
    Write-Host ".\DNSPro.ps1 --asignarip`n"
    Write-Host "Para escribir una nueva configuracion al servidor DNS:"
    Write-Host ".\DNSPro.ps1 --newconfig`n"
    Write-Host "Para reiniciar el servicio:"
    Write-Host ".\DNSPro.ps1 --restartserv`n"
    Write-Host "Modulo de Monitoreo & Pruebas:"
    Write-Host ".\DNSPro.ps1 --monitor`n"
    exit
}

switch ($args[0]) {

    "--verificarinst" {
        verificar_feature "DNS"
        verificar_feature "RSAT-DNS-Server"
        break
    }

    "--instalar" {
        Write-Host "Re/Instalacion de Caracteristicas: `n"
        instalar_feature "DNS"
        instalar_feature "RSAT-DNS-Server"
        break
    }

    "--verificarip" {
        verificarIP | Out-Null
        break
    }

    "--asignarip" {
        verificarIP | Out-Null
        $res = Read-Host "Deseas re/asignar tu direccion IP? s/n"
        if ($res.ToLower() -eq "s") {
            while ($true) {
                $script:claseIP = (Read-Host "Inserta el tipo de clase para la nueva direccion IP: (A, B, C)").ToLower()
                if ($script:claseIP -notin @("a", "b", "c")) { Write-Host "Inserta una clase valida."; continue }
                else { Write-Host "`n"; break }
            }

            while ($true) {
                $dirIP = Read-Host "Inserta la nueva direccion IP"
                if (validacionIP $dirIP) {
                    if (validarNoAptos $dirIP) {
                        sacarMascara $dirIP | Out-Null
                        if (validarMascara) {
                            $prefijo = obtener_cidr $script:claseIP
                            $adapterName = "Ethernet"
                            $existingIP = Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue

                            if ($existingIP) {
                                try {
                                    Set-NetIPAddress -InterfaceAlias $adapterName -IPAddress $existingIP.IPAddress -PrefixLength $prefijo -ErrorAction Stop | Out-Null
                                    $currentIP = (Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4).IPAddress
                                    if ($currentIP -ne $dirIP) {
                                        Remove-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
                                        Start-Sleep -Seconds 1
                                        New-NetIPAddress -InterfaceAlias $adapterName -IPAddress $dirIP -PrefixLength $prefijo -ErrorAction Stop | Out-Null
                                    }
                                }
                                catch {
                                    Remove-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
                                    Start-Sleep -Seconds 2
                                    New-NetIPAddress -InterfaceAlias $adapterName -IPAddress $dirIP -PrefixLength $prefijo -ErrorAction Stop | Out-Null
                                }
                            }
                            else {
                                New-NetIPAddress -InterfaceAlias $adapterName -IPAddress $dirIP -PrefixLength $prefijo -ErrorAction Stop | Out-Null
                            }

                            Disable-NetAdapter -Name $adapterName -Confirm:$false
                            Start-Sleep -Seconds 2
                            Enable-NetAdapter -Name $adapterName -Confirm:$false
                            Write-Host "`n"
                            break
                        }
                        else { Write-Host "Inserta una direccion IP que concuerde con la clase seleccionada."; continue }
                    }
                    else { Write-Host "Inserta una direccion IP valida." }
                }
                else { Write-Host "Inserta una direccion IP con formato valido."; continue }
            }
        }
        else { Write-Host "No se asignara una IP estatica nueva.`n" }
        break
    }

    "--newconfig" {
        while ($true) {
            $svcDNS = Get-Service -Name "DNS" -ErrorAction SilentlyContinue
            if ($svcDNS) {
                Write-Host "El servicio DNS fue encontrado. Verificando estado..."
                if ($svcDNS.Status -eq "Running") { Write-Host "El servicio DNS esta corriendo. Se procedera a actualizarlo." }
                else { Write-Host "El servicio DNS esta detenido. Iniciando configuracion." }

                $adapterIP = obtener_ip_adaptador

                $resIp = (Read-Host "Deseas utilizar la IP local del servidor en la configuracion? s/n").ToLower()
                if ($resIp -eq "s") {
                    $direc = $adapterIP.IPAddress
                }
                else {
                    while ($true) {
                        $direc = Read-Host "Inserta una direccion IP"
                        if (validacionIP $direc) { break }
                        else { Write-Host "Inserta una direccion IP con formato valido." }
                    }
                }

                $ipConf = Get-NetIPAddress -InterfaceAlias "Ethernet" -AddressFamily IPv4 -ErrorAction SilentlyContinue
                if ($ipConf -and $ipConf.PrefixOrigin -ne "Manual") { Write-Host "Primero asigna una IP estatica."; exit 1 }

                $nomZona = Read-Host "Inserta el nombre de la zona DNS"
                if ($nomZona -notmatch "^[a-zA-Z0-9-]+\.[a-zA-Z0-9.-]+$") { Write-Host "Nombre de zona invalido.`n"; continue }

                $zonaExistente = Get-DnsServerZone -Name $nomZona -ErrorAction SilentlyContinue
                if ($zonaExistente) { Write-Host "La zona ya existe."; break }

                try {
                    Add-DnsServerPrimaryZone -Name $nomZona -ZoneFile "$nomZona.dns" -DynamicUpdate None -ErrorAction Stop
                    Write-Host "Zona $nomZona creada correctamente.`n"
                }
                catch { Write-Host "Error al crear la zona: $_"; continue }

                Restart-Service -Name DNS
                Start-Sleep -Seconds 2

                try {
                    foreach ($registro in @("@", "ns1", "www")) {
                        Add-DnsServerResourceRecordA -ZoneName $nomZona -Name $registro -IPv4Address $direc -ErrorAction Stop
                    }
                    Write-Host "Registros A creados correctamente para $nomZona ."
                    Restart-Service -Name DNS
                    break
                }
                catch { Write-Host "Error al agregar registros DNS: $_"; continue }
            }
            else { Write-Host "El servicio DNS no fue encontrado. Instala el rol DNS primero."; break }
        }
        break
    }

    "--restartserv" {
        Restart-Service -Name DNS
        Write-Host "Servicio reiniciado exitosamente.`n"
        break
    }

    "--monitor" {
        while ($true) {
            $nomZona = Read-Host "Inserta el nombre de la zona que buscas"
            if ($nomZona -notmatch "^[a-zA-Z0-9-]+\.[a-zA-Z0-9.-]+$") { Write-Host "Nombre de zona invalido.`n"; continue }

            Write-Host "`nVerificando servicio DNS..."
            $svc = Get-Service -Name "DNS" -ErrorAction SilentlyContinue
            if ($svc -and $svc.Status -eq "Running") { Write-Host "Servicio DNS ACTIVO." }
            else { Write-Host "Servicio DNS INACTIVO."; exit 1 }

            Write-Host "`nVerificando existencia de la zona..."
            $zona = Get-DnsServerZone -Name $nomZona -ErrorAction SilentlyContinue
            if ($zona) { Write-Host "Zona $nomZona encontrada y cargada correctamente." }
            else { Write-Host "Error: la zona $nomZona no existe en el servidor."; exit 1 }

            $direc = (obtener_ip_adaptador).IPAddress

            Write-Host "`nProbando resolucion DNS..."
            $resultado = resolver_dns $nomZona $direc
            if ($resultado -eq $direc) { Write-Host "Resolucion correcta para $nomZona ==> $resultado" }
            else { Write-Host "Resolucion incorrecta."; Write-Host "Esperado: $direc"; Write-Host "Obtenido: $resultado"; exit 1 }

            Write-Host "`nProbando www.$nomZona..."
            $resultadoWWW = resolver_dns "www.$nomZona" $direc
            if ($resultadoWWW -eq $direc) { Write-Host "Resolucion correcta para www.$nomZona ==> $resultadoWWW" }
            else { Write-Host "Resolucion incorrecta para www."; exit 1 }

            Write-Host "`nMONITOREO COMPLETADO EXITOSAMENTE."
            break
        }
        break
    }
}