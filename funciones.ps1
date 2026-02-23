function Verificar {
    param([string]$feature)
    Write-Host "Buscando la caracteristica $feature :"
    $inst = Get-WindowsFeature -Name $feature -ErrorAction SilentlyContinue
    if ($inst -and $inst.Installed) { Write-Host "La caracteristica $feature fue instalada previamente.`n" }
    else { Write-Host "La caracteristica $feature no ha sido instalada.`n" }
}

function Instalar {
    param([string]$feature)
    Verificar $feature
    if ((Get-WindowsFeature -Name $feature).Installed) {
        $res = Read-Host "Deseas reinstalar la caracteristica $feature`? s/n"
        if ($res.ToLower() -eq "s") {
            Write-Host "Reinstalando la caracteristica $feature .`n"
            Uninstall-WindowsFeature -Name $feature | Out-Null
            Install-WindowsFeature -Name $feature -IncludeManagementTools
        }
        else { Write-Host "La instalacion fue cancelada.`n" }
    }
    else {
        $res = Read-Host "Deseas instalar la caracteristica $feature`? s/n"
        if ($res.ToLower() -eq "s") {
            Write-Host "Instalando la caracteristica $feature .`n"
            Install-WindowsFeature -Name $feature -IncludeManagementTools
        }
        else { Write-Host "La instalacion fue cancelada.`n" }
    }
}

function obtener_cidr {
    param([string]$clase)
    switch ($clase) {
        "a" { return 8 }
        "b" { return 16 }
        "c" { return 24 }
    }
}

function obtener_ip_adaptador {
    $adapter = Get-NetIPAddress -InterfaceAlias "Ethernet" -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if (-not $adapter) {
        $adapter = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.*" } |
        Select-Object -First 1
    }
    return $adapter
}

function resolver_dns {
    param([string]$nombre, [string]$servidor)
    return (Resolve-DnsName -Name $nombre -Server $servidor -Type A -ErrorAction SilentlyContinue |
        Where-Object { $_.Type -eq "A" } |
        Select-Object -First 1).IPAddress
}