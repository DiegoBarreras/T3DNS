function ValidacionIP {
    param([string]$ip)
    $regex = "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
    return ($ip -match $regex)
}

function SacarMascara {
    param([string]$ip)
    $octComp = [int]($ip.Split(".")[0])

    if ($octComp -ge 1 -and $octComp -le 126) {
        $script:mask = "255.0.0.0"
        return $true
    }
    elseif ($octComp -ge 128 -and $octComp -le 191) {
        $script:mask = "255.255.0.0"
        return $true
    }
    elseif ($octComp -ge 192 -and $octComp -le 223) {
        $script:mask = "255.255.255.0"
        return $true
    }
    else {
        return $false
    }
}

function ValidarMascara {
    if ($script:mask -eq "255.0.0.0" -and $script:claseIP -ne "a") { return $false }
    if ($script:mask -eq "255.255.0.0" -and $script:claseIP -ne "b") { return $false }
    if ($script:mask -eq "255.255.255.0" -and $script:claseIP -ne "c") { return $false }
    return $true
}

function ValidarNoAptos {
    param([string]$ip)
    $partes = $ip.Split(".")

    if ($partes[0] -eq "127") { return $false }

    if ($script:claseIP -eq "a") {
        $hostPart = "$($partes[1]).$($partes[2]).$($partes[3])"
        if ($hostPart -eq "0.0.0" -or $hostPart -eq "255.255.255") { return $false }
        return $true
    }
    elseif ($script:claseIP -eq "b") {
        $hostPart = "$($partes[2]).$($partes[3])"
        if ($hostPart -eq "0.0" -or $hostPart -eq "255.255") { return $false }
        return $true
    }
    elseif ($script:claseIP -eq "c") {
        if ($partes[3] -eq "0" -or $partes[3] -eq "255") { return $false }
        return $true
    }
    return $false
}

function VerificarIP {
    Write-Host "IP Actual del adaptador de red (Red Interna):"

    $adapter = Get-NetIPAddress -InterfaceAlias "Ethernet" -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if (-not $adapter) {
        $adapter = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.*" } |
        Select-Object -First 1
    }

    if ($adapter) {
        Write-Host $adapter.IPAddress
    }
    else {
        Write-Host "No se pudo obtener la IP del adaptador."
    }

    $adapterFull = Get-NetIPAddress -InterfaceAlias "Ethernet" -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($adapterFull -and $adapterFull.PrefixOrigin -eq "Manual") {
        Write-Host "El adaptador Ethernet ya tiene una IP estatica configurada."
        return $true
    }
    else {
        Write-Host "El adaptador Ethernet aun no tiene una IP fija configurada. Es decir, es dinamica."
        return $false
    }
}

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
        function Verificar {
            param([string]$feature)
            Write-Host "Buscando la caracteristica $feature :"

            $inst = Get-WindowsFeature -Name $feature -ErrorAction SilentlyContinue
            if ($inst -and $inst.Installed) {
                Write-Host "La caracteristica $feature fue instalada previamente.`n"
            }
            else {
                Write-Host "La caracteristica $feature no ha sido instalada.`n"
            }
        }

        Verificar "DNS"
        Verificar "RSAT-DNS-Server"
        break
    }

    "--instalar" {
        function Instalar {
            param([string]$feature)
            Write-Host "Buscando la caracteristica $feature :"

            $inst = Get-WindowsFeature -Name $feature -ErrorAction SilentlyContinue
            $flagSi = $false

            if ($inst -and $inst.Installed) {
                Write-Host "La caracteristica $feature fue instalada previamente.`n"
                $flagSi = $true
            }
            else {
                Write-Host "La caracteristica $feature no ha sido instalada.`n"
                $flagSi = $false
            }

            if (-not $flagSi) {
                $res = Read-Host "Deseas instalar la caracteristica $feature`? s/n"
                if ($res.ToLower() -eq "s") {
                    Write-Host "Instalando la caracteristica $feature .`n"
                    Install-WindowsFeature -Name $feature -IncludeManagementTools
                }
                else {
                    Write-Host "La instalacion fue cancelada.`n"
                }
            }
            else {
                $res = Read-Host "Deseas reinstalar la caracteristica $feature`? s/n"
                if ($res.ToLower() -eq "s") {
                    Write-Host "Reinstalando la caracteristica $feature .`n"
                    Uninstall-WindowsFeature -Name $feature | Out-Null
                    Install-WindowsFeature -Name $feature -IncludeManagementTools
                }
                else {
                    Write-Host "La instalacion fue cancelada.`n"
                }
            }
        }

        Write-Host "Re/Instalacion de Caracteristicas: `n"
        Instalar "DNS"
        Instalar "RSAT-DNS-Server"
        break
    }

    "--verificarip" {
        VerificarIP | Out-Null
        break
    }

    "--asignarip" {
        VerificarIP | Out-Null

        $res = Read-Host "Deseas re/asignar tu direccion IP? s/n"
        if ($res.ToLower() -eq "s") {

            while ($true) {
                $script:claseIP = (Read-Host "Inserta el tipo de clase para la nueva direccion IP: (A, B, C)").ToLower()
                if ($script:claseIP -notin @("a", "b", "c")) {
                    Write-Host "Inserta una clase valida."
                    continue
                }
                else {
                    Write-Host "`n"
                    break
                }
            }

            while ($true) {
                $dirIP = Read-Host "Inserta la nueva direccion IP"

                if (ValidacionIP $dirIP) {
                    if (ValidarNoAptos $dirIP) {
                        SacarMascara $dirIP | Out-Null
                        if (ValidarMascara) {

                            if ($script:claseIP -eq "a") { $prefijo = 8 }
                            elseif ($script:claseIP -eq "b") { $prefijo = 16 }
                            elseif ($script:claseIP -eq "c") { $prefijo = 24 }
                            else {
                                Write-Host "ERROR: No hay un tipo de clase especifico."
                                exit 1
                            }

                            $adapterName = "Ethernet"
                            $existingIP = Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue
                            if ($existingIP) {
                                Remove-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
                            }

                            New-NetIPAddress `
                                -InterfaceAlias $adapterName `
                                -IPAddress $dirIP `
                                -PrefixLength $prefijo `
                                -ErrorAction Stop | Out-Null
                            \
                            Disable-NetAdapter -Name $adapterName -Confirm:$false
                            Start-Sleep -Seconds 2
                            Enable-NetAdapter -Name $adapterName -Confirm:$false

                            Write-Host "`n"
                            break

                        }
                        else {
                            Write-Host "Inserta una direccion IP que concuerde con la clase seleccionada."
                            continue
                        }
                    }
                    else {
                        Write-Host "Inserta una direccion IP valida."
                    }
                }
                else {
                    Write-Host "Inserta una direccion IP con formato valido."
                    continue
                }
            }

        }
        else {
            Write-Host "No se asignara una IP estatica nueva.`n"
        }
        break
    }

    "--newconfig" {
        while ($true) {
            $namedConf = "C:\Windows\System32\dns\named.conf"  
            $zoneDir = "C:\Windows\System32\dns"

            $svcDNS = Get-Service -Name "DNS" -ErrorAction SilentlyContinue

            if ($svcDNS) {
                Write-Host "El servicio DNS fue encontrado. Verificando estado..."

                if ($svcDNS.Status -eq "Running") {
                    Write-Host "El servicio DNS esta corriendo. Se procedera a actualizarlo."
                }
                else {
                    Write-Host "El servicio DNS esta detenido. Iniciando configuracion."
                }

                $adapterIP = Get-NetIPAddress -InterfaceAlias "Ethernet" -AddressFamily IPv4 -ErrorAction SilentlyContinue
                if (-not $adapterIP) {
                    $adapterIP = Get-NetIPAddress -AddressFamily IPv4 |
                    Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.*" } |
                    Select-Object -First 1
                }
                $direc = $adapterIP.IPAddress

                $ipConf = Get-NetIPAddress -InterfaceAlias "Ethernet" -AddressFamily IPv4 -ErrorAction SilentlyContinue
                if ($ipConf -and $ipConf.PrefixOrigin -ne "Manual") {
                    Write-Host "Primero asigna una IP estatica."
                    exit 1
                }

                $nomZona = Read-Host "Inserta el nombre de la zona DNS"

                if ($nomZona -notmatch "^[a-zA-Z0-9-]+\.[a-zA-Z0-9.-]+$") {
                    Write-Host "Nombre de zona invalido.`n"
                    continue
                }

                $zonaExistente = Get-DnsServerZone -Name $nomZona -ErrorAction SilentlyContinue
                if ($zonaExistente) {
                    Write-Host "La zona ya existe."
                    continue
                }

                try {
                    Add-DnsServerPrimaryZone `
                        -Name $nomZona `
                        -ZoneFile "$nomZona.dns" `
                        -DynamicUpdate None `
                        -ErrorAction Stop

                    Write-Host "Zona $nomZona creada correctamente.`n"
                }
                catch {
                    Write-Host "Error al crear la zona: $_"
                    continue
                }

                Restart-Service -Name DNS
                Start-Sleep -Seconds 2

                try {
                    Add-DnsServerResourceRecordA `
                        -ZoneName $nomZona `
                        -Name "@" `
                        -IPv4Address $direc `
                        -ErrorAction Stop

                    Add-DnsServerResourceRecordA `
                        -ZoneName $nomZona `
                        -Name "ns1" `
                        -IPv4Address $direc `
                        -ErrorAction Stop

                    Add-DnsServerResourceRecordA `
                        -ZoneName $nomZona `
                        -Name "www" `
                        -IPv4Address $direc `
                        -ErrorAction Stop

                    Write-Host "Registros A creados correctamente para $nomZona ."
                    Restart-Service -Name DNS
                    break

                }
                catch {
                    Write-Host "Error al agregar registros DNS: $_"
                    continue
                }

            }
            else {
                Write-Host "El servicio DNS no fue encontrado. Instala el rol DNS primero."
                break
            }
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

            if ($nomZona -notmatch "^[a-zA-Z0-9-]+\.[a-zA-Z0-9.-]+$") {
                Write-Host "Nombre de zona invalido.`n"
                continue
            }

            Write-Host "`nVerificando servicio DNS..."
            $svc = Get-Service -Name "DNS" -ErrorAction SilentlyContinue
            if ($svc -and $svc.Status -eq "Running") {
                Write-Host "Servicio DNS ACTIVO."
            }
            else {
                Write-Host "Servicio DNS INACTIVO."
                exit 1
            }

            Write-Host "`nVerificando existencia de la zona..."
            $zona = Get-DnsServerZone -Name $nomZona -ErrorAction SilentlyContinue
            if ($zona) {
                Write-Host "Zona $nomZona encontrada y cargada correctamente."
            }
            else {
                Write-Host "Error: la zona $nomZona no existe en el servidor."
                exit 1
            }

            $adapterIP = Get-NetIPAddress -InterfaceAlias "Ethernet" -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if (-not $adapterIP) {
                $adapterIP = Get-NetIPAddress -AddressFamily IPv4 |
                Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.*" } |
                Select-Object -First 1
            }
            $direc = $adapterIP.IPAddress

            Write-Host "`nProbando resolucion DNS..."
            $resultado = (Resolve-DnsName -Name $nomZona -Server $direc -Type A -ErrorAction SilentlyContinue |
                Where-Object { $_.Type -eq "A" } |
                Select-Object -First 1).IPAddress

            if ($resultado -eq $direc) {
                Write-Host "Resolucion correcta para $nomZona ==> $resultado"
            }
            else {
                Write-Host "Resolucion incorrecta."
                Write-Host "Esperado: $direc"
                Write-Host "Obtenido: $resultado"
                exit 1
            }

            Write-Host "`nProbando www.$nomZona..."
            $resultadoWWW = (Resolve-DnsName -Name "www.$nomZona" -Server $direc -Type A -ErrorAction SilentlyContinue |
                Where-Object { $_.Type -eq "A" } |
                Select-Object -First 1).IPAddress

            if ($resultadoWWW -eq $direc) {
                Write-Host "Resolucion correcta para www.$nomZona ==> $resultadoWWW"
            }
            else {
                Write-Host "Resolucion incorrecta para www."
                exit 1
            }

            Write-Host "`nMONITOREO COMPLETADO EXITOSAMENTE."
            break
        }
        break
    }

}