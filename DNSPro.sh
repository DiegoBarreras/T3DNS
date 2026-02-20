validacionIP() {
        local ip=$1
        local regex="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
        if [[ $ip =~ $regex ]]; then
                return 0
        else
                return 1
        fi
}

sacarMascara() {
        local ip=$1
        local octComp=$(echo $ip | cut -d. -f1)

        if (($octComp <= "126" && $octComp >= "1")); then
                mask="255.0.0.0"
                return 0
        elif (($octComp >= "128" && $octComp <= "191")); then
                mask="255.255.0.0"
                return 0
        elif (($octComp >= "192" && $octComp <= "223")); then
                mask="255.255.255.0"
		return 0
        else
                return 1
        fi
}

validarMascara() {
	if [[ $mask == "255.0.0.0" && $claseIP != "a" ]]; then
                return 1
	elif [[ $mask == "255.255.0.0" && $claseIP != "b" ]]; then
                return 1
	elif [[ $mask == "255.255.255.0" && $claseIP != "c" ]]; then
                return 1
	else
		return 0
	fi
}

validarNoAptos() {
	local ip=$1

	if [[ $(echo $ip | cut -d. -f1) == "127" ]]; then
		return 1
	elif [[ $claseIP == "a" ]]; then
		if [[ $(echo $ip | cut -d. -f2-4) == "0.0.0" || $(echo $ip | cut -d. -f2-4) == "255.255.255" ]]; then
			return 1
		else
			return 0
		fi
	elif [[ $claseIP == "b" ]]; then
                if [[ $(echo $ip | cut -d. -f3-4) == "0.0" || $(echo $ip | cut -d. -f3-4) == "255.255" ]]; then
                        return 1
		else
			return 0
                fi
        elif [[ $claseIP == "c" ]]; then
                if [[ $(echo $ip | cut -d. -f4) == "0" || $(echo $ip | cut -d. -f4) == "255" ]]; then
                        return 1
		else
			return 0
                fi
	fi
}

verificarip() {
	echo "IP Actual de la tarjeta de red (Red Interna):"
	ip addr show enp0s8 | grep "inet " | awk '{print $2}' | cut -d/ -f1

	metodo=$(nmcli -f ipv4.method con show "red_interna" | awk '{print $2}')

	if [[ $metodo == "manual" ]]; then
		echo "La tarjeta de red enp0s8 ya tiene una IP estatica configurada."
		return 0
	else
		echo "La tarjeta de red enp0s8 aun no tiene una IP fija configurada. Es decir, es dinamica."
		return 1
	fi		
}

if [[ $# -eq 0 ]]; then
	echo -e "\n"
	echo -e "---------------------------------------------"
	echo -e "---------- MENU SCRIPT DNS SERVER -'---------"
	echo -e "---------------------------------------------\n"

	echo -e "Para verificar la instalacion de los paquetes:"
	echo -e "./DNSPro.sh --verificarinst\n"

	echo -e "Para re/instalar los paquetes:"
	echo -e "./DNSPro.sh --instalar\n"

	echo -e "Para verificar la IP:"
	echo -e "./DNSPro.sh --verificarip\n"

    echo -e "Para asignar una IP estática:"
	echo -e "./DNSPro.sh --asignarip\n"

	echo -e "Para escribir una nueva configuracion al servidor DNS:"
	echo -e "./DNSPro.sh --newconfig\n"

	echo -e "Para mostrar la configuracion actual:"
	echo -e "./DNSPro.sh --verconfig\n"

	echo -e "Para reiniciar el servicio:"
    echo -e "./DNSPro.sh --restartserv\n"

    echo -e "Módulo de Monitoreo:"
    echo -e "./DNSPro.sh --monitor\n"

    echo -e "Pruebas de DNS:"
    echo -e "./DNSPro.sh --pruebasdns\n"
fi

case $1 in
	--verificarinst)
		verificar() {
			local paq=$1
			echo "Buscando al paquete $paq:"

			if rpm -q $paq &> /dev/null; then
				echo -e "El paquete $paq fue instalado previamente.\n";
			else
				echo -e "El paquete $paq no ha sido instalado.\n"
			fi
		}

		verificar "bind"
		verificar "bind-utils"
		verificar "bind-doc"

		exit 0;
	;;

	--instalar)
		instalar() {
			local paq=$1
			echo "Buscando al paquete $paq:"
			if rpm -q $paq &> /dev/null; then
				echo -e "El paquete $paq fue instalado previamente.\n";
				flagSi=1
			else
				echo -e "El paquete $paq no ha sido instalado.\n"
				flagSi=0
			fi

			if [[ $flagSi == "0" ]]; then
				read -p "Deseas instalar el paquete $paq? s/n " res
				res=${res,,}
				if [[ $res == "s" ]]; then
					echo -e "Instalando el paquete $paq.\n"
					sudo dnf install -y $paq
				else
					echo -e "La instalacion fue cancelada.\n"
				fi
			else
				read -p "Deseas reinstalar el paquete $paq? s/n " res
				res=${res,,}
				if [[ $res == "s" ]]; then
					echo -e "Reinstalando el paquete $paq.\n"
					sudo dnf reinstall -y $paq
				else
					echo -e "La instalacion fue cancelada.\n"
				fi
			fi 
		}

		echo -e "Re/Instalacion de Paquetes: \n"
		instalar "bind"
		instalar "bind-utils"
		instalar "bind-doc"
	;;

    --verificarip)
		verificarip
    ;;

    --asignarip)
		verificarip
		read -p "Deseas re/asignar tu direccion IP? s/n " res
		res=${res,,}
		if [[ $res == "s" ]]; then
			while true; do
				read -p "Inserta el tipo de clase para la nueva direccion IP: (A, B, C) " claseIP
				claseIP=${claseIP,,}

				if [[ $claseIP != "a"  && $claseIP != "b" && $claseIP != "c" ]]; then
					echo "Inserta una clase valida."
					continue
				else
					echo -e "\n"
					break
				fi
			done

			while true; do
				read -p "Inserta la nueva direccion IP: " dirIP
				if validacionIP "$dirIP"; then
					if validarNoAptos "$dirIP"; then
						sacarMascara "$dirIP"
						if validarMascara; then
							#oct4Ini=$(echo $dirIP | cut -d. -f4)
							if [[ $claseIP == "a" ]]; then
								prefijoF="/8"
							elif [[ $claseIP == "b" ]]; then
								prefijoF="/16"
							elif [[ $claseIP == "c" ]]; then
								prefijoF="/24"
							else
								echo "ERROR: No hay un tipo de clase especifico."
								exit 0
							fi

							sudo nmcli connection modify "red_interna" \
								ipv4.method manual \
								ipv4.addresses "${dirIP}${prefijoF}"

							sudo nmcli connection down "red_interna"
							sudo nmcli connection up "red_interna"

							echo -e "\n"
							break
						else
							echo "Inserta una direccion IP que concuerde con la clase seleccionada."
							continue
						fi
					else
						echo "Inserta una direccion IP valida."
					fi
				else
					echo "Inserta una direccion IP con formato valido."
					continue
				fi
			done
		else
			echo -e "No se asignara una IP estatica nueva.\n"
		fi
    ;;

	--newconfig)
    	while true; do
			if [[ -f "/etc/named.conf" ]]; then
				echo "El archivo named.conf fue encontrado. Guardando... "
				if systemctl is-active --quiet named; then
					echo "El servicio named esta corriendo. Se procedera a apagarlo para actualizar la configuracion."
					sudo systemctl stop named
				else
					echo "El servicio named esta detenido. Iniciando configuracion desde cero."
				fi

				nmcli connection show
				metodo=$(nmcli -g ipv4.method connection show "NOMBRE_DE_LA_CONEXION")
				direc=$(nmcli -g IP4.ADDRESS device show | cut -d/ -f1)

				if [[ $metodo == "auto" ]]; then
					echo "Primero asigna una IP estática."
					exit 1
				fi

				sudo sed -i "/listen-on port 53/c\listen-on port 53 { 127.0.0.1; ${direc}; };" /etc/named.conf
				sudo sed -i "s/allow-query     { localhost; };/allow-query     { any; };/" /etc/named.conf

				read -p "Inserta el nombre de la zona DNS: " nomZona

				if [[ ! $nomZona =~ ^[a-zA-Z0-9-]+\.[a-zA-Z0-9.-]+$ ]]; then
					echo "Nombre de zona inválido."
					continue
				fi

				if grep -q "zone \"$nomZona\"" /etc/named.conf; then
					echo "La zona ya existe."
					continue
				else

sudo tee -a /etc/named.conf > /dev/null <<EOF

zone "$nomZona" IN {
	type master;
	file "/var/named/$nomZona.zone";
	allow-update { none; };
};

EOF
	
				sudo named-checkconf /etc/named.conf
				fi

				if [ $? -ne 0 ]; then
					echo "Error de sintaxis en /etc/named.conf."
					continue
				else 
					echo -e "Archivo /etc/named.conf correctamente actualizado.\n"
					sudo systemctl restart named
					break
				fi
			else
				echo "El archivo named.conf no fue encontrado.."
				continue
			fi
		done
	;;
esac