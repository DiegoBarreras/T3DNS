function validacionIP {
    param([string]$ip)
    $regex = "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
    return ($ip -match $regex)
}

function sacarMascara {
    param([string]$ip)
    $octComp = [int]($ip.Split(".")[0])
    if ($octComp -ge 1 -and $octComp -le 126) { $script:mask = "255.0.0.0"; return $true }
    elseif ($octComp -ge 128 -and $octComp -le 191) { $script:mask = "255.255.0.0"; return $true }
    elseif ($octComp -ge 192 -and $octComp -le 223) { $script:mask = "255.255.255.0"; return $true }
    else { return $false }
}

function validarMascara {
    if ($script:mask -eq "255.0.0.0" -and $script:claseIP -ne "a") { return $false }
    if ($script:mask -eq "255.255.0.0" -and $script:claseIP -ne "b") { return $false }
    if ($script:mask -eq "255.255.255.0" -and $script:claseIP -ne "c") { return $false }
    return $true
}

function validarNoAptos {
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

function verificarIP {
    Write-Host "IP Actual del adaptador de red (Red Interna):"
    $adapter = obtener_ip_adaptador
    if ($adapter) { Write-Host $adapter.IPAddress }
    else { Write-Host "No se pudo obtener la IP del adaptador." }

    $adapterFull = Get-NetIPAddress -InterfaceAlias "Ethernet" -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($adapterFull -and $adapterFull.PrefixOrigin -eq "Manual") {
        Write-Host "El adaptador red_interna ya tiene una IP estatica configurada."
        return $true
    }
    else {
        Write-Host "El adaptador red_interna aun no tiene una IP fija configurada. Es decir, es dinamica."
        return $false
    }
}

function verificar_paquete {
    $dhcpService = Get-WindowsFeature -Name DHCP -ErrorAction SilentlyContinue
    if ($dhcpService -and $dhcpService.Installed) { Write-Host "El paquete fue instalado previamente." }
    else { Write-Host "El paquete no ha sido instalado." }
}

function calcular_valor_ip {
    param([string]$ip, [string]$clase)
    $oct = $ip.Split('.')
    switch ($clase) {
        "a" { return [int]$oct[1] * 65536 + [int]$oct[2] * 256 + [int]$oct[3] }
        "b" { return [int]$oct[2] * 256 + [int]$oct[3] }
        "c" { return [int]$oct[3] }
    }
}

function aplicar_ip_servidor {
    param([string]$ip, [int]$prefixLength)
    Remove-NetIPAddress -InterfaceAlias "Ethernet" -Confirm:$false -ErrorAction SilentlyContinue
    New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress $ip -PrefixLength $prefixLength
    Write-Host "Direccion IP actualizada exitosamente."
    netsh advfirewall firewall add rule name="DHCP Server" dir=in action=allow protocol=UDP localport=67
}

function configurar_dns {
    param([string]$subnet, [string]$dns, [string]$dns2)
    try {
        if (-not [string]::IsNullOrWhiteSpace($dns2)) {
            Set-DhcpServerv4OptionValue -ScopeId $subnet -DnsServer $dns, $dns2 -ErrorAction Stop
        }
        else {
            Set-DhcpServerv4OptionValue -ScopeId $subnet -DnsServer $dns -ErrorAction Stop
        }
        Write-Host "DNS configurado correctamente."
    }
    catch {
        Write-Host "Windows no pudo validar el DNS. Intentando metodo alternativo..." -ForegroundColor Yellow
        try {
            $dnsArray = if (-not [string]::IsNullOrWhiteSpace($dns2)) { @($dns, $dns2) } else { @($dns) }
            Set-DhcpServerv4OptionValue -ScopeId $subnet -OptionId 6 -Value $dnsArray -Force -ErrorAction Stop
            Write-Host "DNS configurado exitosamente (metodo alternativo)." -ForegroundColor Green
        }
        catch {
            Write-Host "ADVERTENCIA: No se pudo configurar el DNS automaticamente." -ForegroundColor Red
            if (-not [string]::IsNullOrWhiteSpace($dns2)) {
                Write-Host "Set-DhcpServerv4OptionValue -ScopeId $subnet -OptionId 6 -Value $dns,$dns2 -Force" -ForegroundColor Cyan
            }
            else {
                Write-Host "Set-DhcpServerv4OptionValue -ScopeId $subnet -OptionId 6 -Value $dns -Force" -ForegroundColor Cyan
            }
            Write-Host "El scope fue creado correctamente pero SIN DNS." -ForegroundColor Yellow
        }
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

function verificar_feature {
    param([string]$feature)
    Write-Host "Buscando la caracteristica $feature :"
    $inst = Get-WindowsFeature -Name $feature -ErrorAction SilentlyContinue
    if ($inst -and $inst.Installed) { Write-Host "La caracteristica $feature fue instalada previamente.`n" }
    else { Write-Host "La caracteristica $feature no ha sido instalada.`n" }
}

function instalar_feature {
    param([string]$feature)
    verificar_feature $feature
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