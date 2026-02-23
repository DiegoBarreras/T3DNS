source "$(dirname "$0")/funciones.sh"

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

	echo -e "Para reiniciar el servicio:"
	echo -e "./DNSPro.sh --restartserv\n"

	echo -e "Módulo de Monitoreo & Pruebas:"
	echo -e "./DNSPro.sh --monitor\n"
fi

case $1 in
	--verificarinst)
		verificar_paquete "bind"
		verificar_paquete "bind-utils"
		verificar_paquete "bind-doc"
		exit 0
	;;

	--instalar)
		echo -e "Re/Instalacion de Paquetes: \n"
		instalar_paquete "bind"
		instalar_paquete "bind-utils"
		instalar_paquete "bind-doc"
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
				if [[ $claseIP != "a" && $claseIP != "b" && $claseIP != "c" ]]; then
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
							prefijoF=$(obtener_cidr $claseIP)
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

				metodo=$(nmcli -g ipv4.method connection show "red_interna")
				direcDNS=$(nmcli -g IP4.ADDRESS device show enp0s8 | cut -d/ -f1)

				read -p "Deseas utilizar la IP local del servidor en la configuracion? s/n " resIp
				resIp=${resIp,,}
				if [[ $resIp == "s" ]]; then
					direc=$(nmcli -g IP4.ADDRESS device show enp0s8 | cut -d/ -f1)
				else
					read -p "Inserta una IP valida:" direc
				fi

				if [[ $metodo == "auto" ]]; then
					echo "Primero asigna una IP estática."
					exit 1
				fi

				sudo sed -i "s|listen-on port 53 {.*};|listen-on port 53 { 127.0.0.1; ${direcDNS}; };|" /etc/named.conf
				sudo sed -i "s/allow-query     { localhost; };/allow-query     { any; };/" /etc/named.conf

				read -p "Inserta el nombre de la zona DNS: " nomZona

				if [[ ! $nomZona =~ ^[a-zA-Z0-9-]+\.[a-zA-Z0-9.-]+$ ]]; then
					echo -e "Nombre de zona inválido.\n"
					continue
				fi

				if grep -q "zone \"$nomZona\"" /etc/named.conf; then
					echo "La zona ya existe."
					break
				else

sudo tee -a /etc/named.conf > /dev/null <<EOF

zone "$nomZona" IN {
	type master;
	file "/var/named/$nomZona.zone";
	allow-update { none; };
};

EOF

				verificar_sintaxis_named
				fi

				if [ $? -ne 0 ]; then
					echo "Error de sintaxis en /etc/named.conf."
					continue
				else
					echo -e "Archivo /etc/named.conf correctamente actualizado.\n"
					sudo systemctl restart named

					if [[ -f "/var/named/$nomZona.zone" ]]; then
						echo "La zona ya existe."
						break
					else

sudo tee /var/named/$nomZona.zone > /dev/null <<EOF
\$TTL 86400
@   IN  SOA ns1.$nomZona. admin.$nomZona. (
        2026022001 ; Serial
        3600       ; Refresh
        1800       ; Retry
        604800     ; Expire
        86400 )    ; Minimum TTL

@       IN  NS      ns1.$nomZona.
ns1     IN  A       $direc
@       IN  A       $direc
www     IN  A       $direc
EOF

						sudo named-checkzone $nomZona /var/named/$nomZona.zone
						if [ $? -ne 0 ]; then
							echo "Error de sintaxis en /var/named/$nomZona.zone."
							continue
						else
							sudo systemctl restart named
							recargar_firewall_dns
							break
						fi
					fi
				fi
			else
				echo "El archivo named.conf no fue encontrado.."
				continue
			fi
		done
	;;

	--restartserv)
		sudo systemctl restart named
		echo -e "Servicio reiniciado exitosamente.\n"
	;;

	--monitor)
		while true; do
			read -p "Inserta el nombre de la zona que buscas: " nomZona

			if [[ ! $nomZona =~ ^[a-zA-Z0-9-]+\.[a-zA-Z0-9.-]+$ ]]; then
				echo -e "Nombre de zona inválido.\n"
				continue
			fi

			echo -e "\nVerificando servicio DNS..."
			if systemctl is-active --quiet named; then
				echo "Servicio named ACTIVO."
			else
				echo "Servicio named INACTIVO."
				exit 1
			fi

			echo -e "\nVerificando sintaxis de named.conf..."
			if verificar_sintaxis_named; then
				echo "Sintaxis correcta en named.conf."
			else
				echo "Error en sintaxis de named.conf."
				exit 1
			fi

			echo -e "\nVerificando archivo de zona..."
			if sudo named-checkzone $nomZona /var/named/$nomZona.zone; then
				echo "Sintaxis de zona $nomZona correcta."
			else
				echo "Error en archivo de zona."
				exit 1
			fi

			direc=$(nmcli -g IP4.ADDRESS device show enp0s8 | head -n1 | cut -d/ -f1)
			echo -e "\nProbando resolucion DNS..."

			resultado=$(nslookup $nomZona $direc 2>/dev/null | awk '/^Address: / {print $2}' | tail -n1)
			if [[ "$resultado" == "$direc" ]]; then
				echo "Resolucion correcta para $nomZona ==> $resultado"
			else
				echo "Resolucion incorrecta."
				echo "Esperado: $direc"
				echo "Obtenido: $resultado"
				exit 1
			fi

			echo -e "\nProbando www.$nomZona..."
			resultadoWWW=$(nslookup www.$nomZona $direc 2>/dev/null | awk '/^Address: / {print $2}' | tail -n1)
			if [[ "$resultadoWWW" == "$direc" ]]; then
				echo "Resolucion correcta para www.$nomZona ==> $resultadoWWW"
			else
				echo "Resolucion incorrecta para www."
				exit 1
			fi

			echo -e "\nMONITOREO COMPLETADO EXITOSAMENTE."
			break
		done
	;;
esac