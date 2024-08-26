# I bash people for fun - Osama Bin Bash

Mail1="$HOME/.vinmail/.Mail1"
Mail2="$HOME/.vinmail/.Mail2"
Mail3="$HOME/.vinmail/.Mail3"
mainfilo="$HOME/.msmtprc"

greetings=("¡Hola" "Hello" "Bonjour" "Salut" "Namaste (नमस्ते)" "Konnichiwa (こんにちは)" "Ciao" "NiHao (你好)" "Privet (Привет)")
len=${#greetings[@]}
index=$(($RANDOM % $len))
echo "${greetings[$index]}, YourName!" # Change YourName to your name
echo "Choose your mail to use:"
mailos=("<example1@domain.com>" "<example2@gmail.com>" "<example3@domain.dev>") # Change the mails to your mails
taken=0
vinmails() {
	for i in "${!mailos[@]}"; do
		if [ $i -eq $taken ]; then
			echo -e "\r->  ${mailos[$i]}"
		else
			echo -e "\r   ${mailos[$i]}"
		fi
	done
}
while true; do
	vinmails
	read -rsn1 input
	case $input in
		j) ((taken++)) # Press j to go down
			if [ $taken -ge ${#mailos[@]} ]; then
				taken=0
			fi
			;;
		k) ((taken--)) # Press k to go up
			if [ $taken -lt 0 ]; then
				taken=$((${#mailos[@]} - 1))
			fi
			;;
		"") # Press Return/Space to select
			case $taken in
				0) cp "$Mail1" "$mainfilo"
					echo "You are now using ${mailos[0]}."
					;;
				1) cp "$Mail2" "$mainfilo"
					echo "You are now using ${mailos[1]}."
					;;
				2) cp "$Mail3" "$mainfilo"
					echo "You are now using ${mailos[2]}."
					;;
			esac
			chmod 600 "$mainfilo"
			break
			;;
	esac
	for i in ${!mailos[@]}; do
		echo -ne "\033[1A"
	done
done
