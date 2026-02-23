verificar_paquete() {
	local paq=$1
	echo "Buscando al paquete $paq:"
	if rpm -q $paq &> /dev/null; then
		echo -e "El paquete $paq fue instalado previamente.\n"
	else
		echo -e "El paquete $paq no ha sido instalado.\n"
	fi
}

instalar_paquete() {
	local paq=$1
	verificar_paquete $paq
	if rpm -q $paq &> /dev/null; then
		read -p "Deseas reinstalar el paquete $paq? s/n " res
		res=${res,,}
		if [[ $res == "s" ]]; then
			echo -e "Reinstalando el paquete $paq.\n"
			sudo dnf reinstall -y $paq
		else
			echo -e "La instalacion fue cancelada.\n"
		fi
	else
		read -p "Deseas instalar el paquete $paq? s/n " res
		res=${res,,}
		if [[ $res == "s" ]]; then
			echo -e "Instalando el paquete $paq.\n"
			sudo dnf install -y $paq
		else
			echo -e "La instalacion fue cancelada.\n"
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

obtener_cidr() {
	local clase=$1
	case $clase in
		"a") echo "/8" ;;
		"b") echo "/16" ;;
		"c") echo "/24" ;;
	esac
}

recargar_firewall_dns() {
	sudo firewall-cmd --add-service=dns --permanent
	sudo firewall-cmd --reload
}

verificar_sintaxis_named() {
	sudo named-checkconf /etc/named.conf
	return $?
}