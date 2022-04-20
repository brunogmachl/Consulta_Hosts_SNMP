#!/usr/bin/env bash
##############################
#        EQUIPE VOC          #
##############################    
##############################

###########################
# pastas principais       #
###########################
# status_name_new         #
# status_canal_new        #
# CONSULTA_RESUMIDA       #
# CONSULTA_DETALHADA      #
###########################

#############################################
#PACOTES NECESSARIOS                        #
#apt-get install snmp-mibs-downloader       #
#apt-get install net-tools                  #
#apt-get install snmp                       ################
#importar modulos cisco para a pasta /usr/share/snmp/mibs  #
############################################################

######################################################################################################################################
#/etc/snmp/snmpd.conf --> entrar nesse diretorio e comentar as duas ultimas linhas e mudar o ip da primeira de localhost --> 0.0.0.0 #
#agentAddress  udp:0.0.0.0:161					   ###################################################################
#Listen for connections on all interfaces (both IPv4 *and* IPv6)   #
#agentAddress udp:161,udp6:[::1]:161				   #
####################################################################

#########################################################################################################
#netstat -puln  --> comando para verificar se a porta 161(snmp) esta aberta para acesso externo 0.0.0.0 #
#/etc/snmp/snmp.conf  --> entrar nesse diretorio e inserir na ultima linha -->   mibs +ALL              #
#service snmpd restart  ---> reinicar o serviço #########################################################
#################################################


function coleta_snmp_walk_arquivos(){
        HOST=$(echo ${end_indice} | sed -r 's/(^\w+) (([0-9]+\.?)+) ([A-Za-z0-9@]+)/\1/g')
        IP=$(echo ${end_indice} | sed -r 's/(^\w+) (([0-9]+\.?)+) ([A-Za-z0-9@]+)/\2/g')
        COMUNIDADE=$(echo ${end_indice} | sed -r 's/(^\w+) (([0-9]+\.?)+) ([A-Za-z0-9@]+)/\4/g')
        snmpwalk -v 2c -c $COMUNIDADE $IP -Ir dcmCfgSrvOutputServiceName &> /dev/null >> status_name_temporario
                if [ $? -ne 0 ] # caso tenha falha na comunicacao ou time out
                then
                echo "$IP ====> Failed"
                echo " "
                echo "$IP" >>  CONSULTA_RESUMIDA;
                echo "STATUS CANAL" >> status_canal_new
                echo "$HOST $IP" >> status_name_new; echo "Failed">> status_name_new; echo "Failed">> status_canal_new
                echo "Failed" >> CONSULTA_RESUMIDA; echo "Failed" >> CONSULTA_RESUMIDA; echo "Failed" >> CONSULTA_RESUMIDA
                cat CONSULTA_RESUMIDA | sed '$a \ ' > CONSULTA_RESUMIDA_TEMPORARIA # inserindo linha em branco no final
                cat CONSULTA_RESUMIDA_TEMPORARIA > CONSULTA_RESUMIDA #obrigatorio inserir  > para nao duplicar o arquivo >>>>> CONSULTA_RESUMIDA com linha no fin$
                rm CONSULTA_RESUMIDA_TEMPORARIA
                return 1
                fi
        snmpwalk -v 2c -c $COMUNIDADE $IP -Ir dcmCfgSrvState &> /dev/null >> status_canal_temporario   ##antigo >>>>> status_canal_new
        echo "$HOST $IP ====> OK"
        echo " "
        sleep 1

}


##########################################################################################################################################################
## a funcao acima entrega a pasta (status_canal_temporario ---> status_filtrando_status_canal) e (status_name_temporario ---> função Numero_Nome_Canais)##
##########################################################################################################################################################

function separando_numero_nome_canais(){

        # o sed abaixo coloca o sid e nome do canal no final da linha pelo retrovisor, e o grep filtra o SSID + NOME_CANAL
        sed -r 's/([0-9]+\.[0-9]+) = \w+: "(ALL(\w+| )+(\w+|  ?)+)/.\1 \2/g' status_name_temporario |\
        grep -Eo '[[:digit:]]+\.[[:digit:]]+ +ALL +IP +(\w+| +)+'>>status_name_temporario_filtrado #pasta com o nome e numero do canal formatado
        cat status_name_temporario_filtrado | cut -sf1 -d" " > status_pegando_numero_canais # pega apenas o numero do canal e redireciona para outra pasta
        cat status_name_temporario_filtrado | cut -f1 -d" " --complement  >>status_name_new #pega apenas o nome do canal e redireciona para outra pasta
        rm  status_name_temporario status_name_temporario_filtrado

        TOTAL=$(cat status_name_new | wc -l)
        echo "$TOTAL   TOTAL" >> CONSULTA_RESUMIDA_TEMPORARIA  # | sed -i '$s/$/  TOTAL/'

        cat status_name_new | sed "1i$HOST $IP" >> recebe_ip_primeira_linha # inserindo ip na primeira linha
        cat recebe_ip_primeira_linha > status_name_new # obrigatorio sobrescrever  > para nao duplicar o arquivo definitivo
        rm recebe_ip_primeira_linha
}

###########################################################  interecao com o usuario  ############################################################

function status_filtrando_status_canal(){

        caminho=$(cat /home/bruno/pasta_bkp/pastanew3.sh/status_pegando_numero_canais)
        IFS_ORIGINAL=$IFS
        IFS=$'\n'
        for numero_canal in $caminho; # NAVARIAVEL NUMERO_CANAL CONSTA O (IDENTIFICADOR.NUMERO) DO CANAL OU OUTRO CODIGO QUALQUER EX:100000000.518
        do

                cat /home/bruno/pasta_bkp/pastanew3.sh/status_canal_temporario | grep -E "\.$numero_canal" |rev | cut -c 2 >> status_canal_new

        done
        IFS=$IFS_ORIGINAL
        rm status_canal_temporario &> /dev/null #removendo pasta principal que recebe o status de todos os canais para um novo loop
        sed -e 's/1/OK/' -e 's/2/Failed/' status_canal_new >> status_canal_temporario_new
        cat status_canal_temporario_new > status_canal_new # obrigatorio usar  > para nao duplicar o arquivo
        rm status_canal_temporario_new

        OK=$(sed '/OK$/!d' status_canal_new  | wc -l) # >> CONSULTA_RESUMIDA_TEMPORARIA   #| sed -i '$s/$/   OK/' CONSULTA_RESUMIDA_TEMPORARIA >\
        echo "$OK   OK" >> CONSULTA_RESUMIDA_TEMPORARIA

        FAILED=$(sed '/Failed$/!d' status_canal_new  | wc -l)   # >> CONSULTA_RESUMIDA_TEMPORARIA  # | sed -i '$s/$/   Failed/' CONSULTA_RESUMIDA_TEMPORARIA > \
        echo "$FAILED   Failed" >> CONSULTA_RESUMIDA_TEMPORARIA

        cat CONSULTA_RESUMIDA_TEMPORARIA | sed "1i$HOST-$IP" >> CONSULTA_RESUMIDA  #colocando o ip na primeira linha apos contar a quantidade de eventos pelas linhas ($
        cat CONSULTA_RESUMIDA | sed '$a \ ' > CONSULTA_RESUMIDA_TEMPORARIA # inserindo linha em branco no final
        cat CONSULTA_RESUMIDA_TEMPORARIA > CONSULTA_RESUMIDA #obrigatorio inserir  > para nao duplicar o arquivo >>>>> CONSULTA_RESUMIDA com linha no final em br$
        cat status_canal_new | sed '1i STATUS CANAL' >recebe_status_canal_primeira_linha
        cat recebe_status_canal_primeira_linha > status_canal_new # obrigatorio usar  > para nao duplicar o arquivo, (arquivo status_canal_new FINALIZADA)

        rm CONSULTA_RESUMIDA_TEMPORARIA recebe_status_canal_primeira_linha
}


function juntando_pastas_principais(){

        pr -m -t status_name_new status_canal_new >>status_juntando_Name_New_Canal_New #comando os dois resultados --> SID STATUS_SID
        cat status_juntando_Name_New_Canal_New >> CONSULTA_DETALHADA #arquivo de log
        cat CONSULTA_DETALHADA | sed '$a \ ' > CONSULTA_DETALHADA_TEMPORARIA # inserindo linha em branco no final
        cat CONSULTA_DETALHADA_TEMPORARIA > CONSULTA_DETALHADA #obrigatorio inserir  > para nao duplicar o arquivo
        rm CONSULTA_DETALHADA_TEMPORARIA status_name_new  status_canal_new status_juntando_Name_New_Canal_New status_pegando_numero_canais &> /dev/null  #removan$
 

}


function coluna_dcm_read_usuario(){
	clear
	rm status* &> /dev/null
        rm CONSULTA* &> /dev/null
echo "--------------------------------------------------
SEJA BEM VINDO AO SISTEMA DE CONSULTAS ALL IP...
--------------------------------------------------
                                     "
	sleep 5
	clear
	unset end_new #reinicia a variavel
	cat ./COLUNA_FINAL_NEW.sh #imprime na tela todas as opcoes de DCMs
        echo " "
	read -a codigo_dcm_total -p "Informe os codigos do DCM ou SAIR para cancelar a opareção: "
        echo " "
	verificando_usuario_sair
}

function verificando_usuario_sair(){
	clear
	unset valores_errados
	#echo "VALIDANDO SE O USUARIO DESEJA SAIR..."
	#sleep 5
	#clear
	local let contador=0
	for valor_digitado in ${codigo_dcm_total[@]}
	do
        	valor_digitado_new=$(echo $valor_digitado | tr [:lower:] [:upper:])
	   	if [ $valor_digitado_new = 'SAIR' ]
             	then
                	    #echo "ENCERRANDO ==> VOLTE SEMPRE =]..."
			    #sleep 4
			    local valores_errados[$contador]=$valor_digitado_new
		fi
        done
	if [ ${#valores_errados[@]} -gt 0 ]
        then
		echo "ENCERRANDO ==> OK VOLTE SEMPRE =]..."
		sleep 5
		clear
                exit 1
        else
		validando_informacoes_usuario
	fi
}


function validando_informacoes_usuario(){
	#clear
	unset valores_usuario_errado
	local valores_usuario_errado
	echo "VALIDANDO INFORMACOES DIGITADAS PELO USUARIO..."
	sleep 5
	#clear
	local let contador_usuario=0
	for valor_digitado in ${codigo_dcm_total[@]}
	do
        	#if [ $valor_digitado -lt 1 -o $valor_digitado -gt 138 ] 2> /dev/null  # menor que 1 E maior que 138
		if [[ $valor_digitado =~ [^[:digit:]] || $valor_digitado -lt '0' || $valor_digitado -gt '137' ]] 2> /dev/null
		then
			echo "ERRO: ($valor_digitado) NÃO CONSTA NA TABELA DE CODIGOS, REPITA A OPERACAO"
			sleep 4
			valores_usuario_errado[$contador_usuario]=$valor_digitado

		fi
	done
	if [ ${#valores_usuario_errado[@]} -gt 0 ]
	then
		echo "RETORNANDO PARA PAGINA INICIAL..."
		sleep 3
		coluna_dcm_read_usuario
	else
		echo "VALIDACAO OK"
		sleep 3
		formando_nova_array ${codigo_dcm_total[@]}
	fi
}


function formando_nova_array(){
	#clear
	unset end_new
	echo "ACESSANDO INFORMACOES DO SISTEMA VIA SNMP..."
	sleep 4
	clear
	#echo "${codigo_dcm_total[*]} --> imprime todos os elementos "
	#echo "${!codigo_dcm_total[@]} --> quantidade de indices do array"
	#echo "${#codigo_dcm_total[@]} retorna o total de elemntos do array"
	#sleep 40
	#exit 1 
    	local let contador=0  # representa o indice na cricao do vetor
        for codigo in ${codigo_dcm_total[@]} # laco no array criado pelo metodo read -p vindo do usuario
        do

	      codigo_new=$(echo $codigo | sed "s/^0*//g")
	      #echo "############"
	      #echo "ESSE É O VALOR DO INDICE ----->>>>  $codigo_new"
	      #echo "############"
              #sleep 5
	      #local let codigo codigo-=1  #subtraindo os indices  ex: 005 --> 004 ex: 001 --> (000) primeiro elemento do array
              end_new[$contador]="${end["$codigo_new"]}" #criando o novo array que sera encaminhado para execucao da primeira função
              let contador=contador+1 #incrementa 1 no indice para formar o novo array end_new com as informacoes do array end(antigo)
	done


echo " "
echo "========================================================="
echo "   OLA! TOME UM CAFÉ ENQUANTO BUSCO AS INFORMAÇÕES =]..."
echo "========================================================="
echo "               CONSULTA CANAIS ALL IP                    "
echo "========================================================="
echo "ACESSANDO DCM..."
echo " "
solicitacao_final_nova_array ${end_new[@]}


#echo "${end_new[*]} --> imprime todos os elementos "
#sleep 3
#echo "${!end_new[@]} --> quantidade de indices do array"
#sleep 3
#echo "${#end_new[@]} retorna o total de elemntos do array"
#sleep 40
#exit 1
}


###############################################    MENU   #####################################################################

function consulta_resumida()
{
        clear
echo "------------------------------
ACESSANDO ARQUIVO RESUMIDO...
------------------------------
                                "
        sleep 3
        cat /home/bruno/pasta_bkp/pastanew3.sh/CONSULTA_RESUMIDA
	local usuario='2'
	while [[ "$usuario" != '0' ]]
	do
                read -p 'DIGITE 0(ZERO) PARA RETORNAR AO MENU: ' usuario  > /dev/null
        done
	clear
        echo "RETORNANDO..."
        sleep 3
	clear
	consulta_arquivos
}

function consulta_detalhada(){
	clear
echo "------------------------------
ACESSANDO ARQUIVO DETALHADO...
------------------------------
				"
	sleep 3
        cat /home/bruno/pasta_bkp/pastanew3.sh/CONSULTA_DETALHADA
	local usuario='2'
	while [[ "$usuario" != '0' ]]
	do
		read -p 'DIGITE 0(ZERO) PARA RETORNAR AO MENU: ' usuario > /dev/null
	done
	clear
	echo "RETORNANDO..."
	sleep 3
	clear
	consulta_arquivos
}

function consulta_arquivos(){
echo "SELECIONE UMA OPÇÃO VÁLIDA PARA ACESSAR OS ARQUIVOS...
 ""
1) CONSULTA RESUMIDA
2) CONSULTA DETALHADA
3) PESQUISAR NOVAMENTE (DADOS ATUAIS SERÃO PERDIDOS)
4) SAIR"
echo " "
	#sleep 30
	read -p 'DIGITE UM OPÇÃO: ' usuario


	if [ $usuario -eq 1 ]
	then
		clear
		consulta_resumida

	elif [ $usuario -eq 2 ]
        then
		clear
                consulta_detalhada

	elif [ $usuario -eq 3 ]
	then
		clear
echo "-----------------------------------
REDIRECIONANDO PARA NOVA CONSULTA...
-----------------------------------
                                "
		coluna_dcm_read_usuario

	elif [ $usuario -eq 4 ]
	then
		clear
echo "------------------------------
ATÉ LOGO...=]
------------------------------
                                "
		sleep 3
		clear
		exit 1
	else
		clear
echo "------------------------------
DIGITE UMA OPÇÃO VÁLIDA...
------------------------------
  				"
		sleep 3
		clear
		consulta_arquivos

	fi
}


function solicitacao_final_nova_array(){
	for end_indice in "${end_new[@]}";
	do
		#echo "#####arrary do laço#####"
		#echo $end_indice
                #echo "########################"
		#sleep 10
		coleta_snmp_walk_arquivos $end_indice
		if [ $? -ne 0 ]
		then
			juntando_pastas_principais
			continue
	else
		separando_numero_nome_canais
		status_filtrando_status_canal
		juntando_pastas_principais

	fi
done
echo " "
echo "=========================================================="
echo "                  CONSULTA FINALIZADA"
echo "=========================================================="
sleep 5
consulta_arquivos
}

################################################### CANAIS #################################################################

end=("relacoes de hosts.....")

while true;
do

	clear
	coluna_dcm_read_usuario #coluna de DCMs e faz pergunta inicial ao usuario


done


#fim!
