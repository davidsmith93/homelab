PREFIX="cfg_section_"

function cfg_parser {
   shopt -p extglob &> /dev/null
   CHANGE_EXTGLOB=$?
   if [ $CHANGE_EXTGLOB = 1 ]
   then
      shopt -s extglob
   fi
   ini="$(<$1)"                 # read the file
   ini=${ini//$'\r'/}           # remove linefeed i.e dos2unix

   ini="${ini//[/\\[}"
   ini="${ini//]/\\]}"
   OLDIFS="$IFS"
   IFS=$'\n' && ini=( ${ini} )  # convert to line-array
   ini=( ${ini[*]/#*([[:space:]]);*/} )
   ini=( ${ini[*]/#*([[:space:]])\#*/} )
   ini=( ${ini[*]/#+([[:space:]])/} ) # remove init whitespace
   ini=( ${ini[*]/%+([[:space:]])/} ) # remove ending whitespace
   ini=( ${ini[*]/%+([[:space:]])\\]/\\]} ) # remove non meaningful whitespace after sections

   if [ $BASH_VERSINFO == 3 ]
   then
      ini=( ${ini[*]/+([[:space:]])=/=} ) # remove whitespace before =
      ini=( ${ini[*]/=+([[:space:]])/=} ) # remove whitespace after =
      ini=( ${ini[*]/+([[:space:]])=+([[:space:]])/=} ) # remove whitespace around =
   else
      ini=( ${ini[*]/*([[:space:]])=*([[:space:]])/=} ) # remove whitespace around =
   fi

   ini=( ${ini[*]/#\\[/\}$'\n'"$PREFIX"} ) # set section prefix

   for ((i=0; i < "${#ini[@]}"; i++))
   do
      line="${ini[i]}"
      if [[ "$line" =~ $PREFIX.+ ]]
      then
         ini[$i]=${line// /_}
      fi
   done

   ini=( ${ini[*]/%\\]/ \(} )   # convert text2function (1)
   ini=( ${ini[*]/=/=\( } )     # convert item to array
   ini=( ${ini[*]/%/ \)} )      # close array parenthesis
   ini=( ${ini[*]/%\\ \)/ \\} ) # the multiline trick
   ini=( ${ini[*]/%\( \)/\(\) \{} ) # convert text2function (2)
   ini=( ${ini[*]/%\} \)/\}} )  # remove extra parenthesis
   ini=( ${ini[*]/%\{/\{$'\n''cfg_unset ${FUNCNAME/#'$PREFIX'}'$'\n'} )  # clean previous definition of section 
   ini[0]=""                    # remove first element
   ini[${#ini[*]} + 1]='}'      # add the last brace

   eval "$(echo "${ini[*]}")"   # eval the result
   EVAL_STATUS=$?
   if [ $CHANGE_EXTGLOB = 1 ]
   then
      shopt -u extglob
   fi
   IFS="$OLDIFS"
   return $EVAL_STATUS
}

function cfg_unset {
   local item fun newvar vars
   SECTION=$1
   OLDIFS="$IFS"
   IFS=' '$'\n'
   if [ -z "$SECTION" ]
   then
      fun="$(declare -F)"
   else
      fun="$(declare -F $PREFIX$SECTION)"
      if [ -z "$fun" ]
      then
         echo "section $SECTION not found" 1>&2
         return
      fi
   fi
   fun="${fun//declare -f/}"
   for f in $fun; do
      [ "${f#$PREFIX}" == "${f}" ] && continue
      item="$(declare -f ${f})"
      item="${item##*\{}" # remove function definition
      item="${item##*FUNCNAME*$PREFIX\};}" # remove clear section
      item="${item/%\}}"  # remove function close
      item="${item%)*}" # remove everything after parenthesis
      item="${item});" # add close parenthesis
      vars=""
      while [ "$item" != "" ]
      do
         newvar="${item%%=*}" # get item name
         vars="$vars $newvar" # add name to collection
         item="${item#*;}" # remove readed line
      done
      for var in $vars; do
         unset $var
      done
   done
   IFS="$OLDIFS"
}

function cfg_clear {
   SECTION=$1
   OLDIFS="$IFS"
   IFS=' '$'\n'
   if [ -z "$SECTION" ]
   then
      fun="$(declare -F)"
   else
      fun="$(declare -F $PREFIX$SECTION)"
      if [ -z "$fun" ]
      then
         echo "section $SECTION not found" 1>&2
         exit 1
      fi
   fi
   fun="${fun//declare -f/}"
   for f in $fun; do
      [ "${f#$PREFIX}" == "${f}" ] && continue
      unset -f ${f}
   done
   IFS="$OLDIFS"
}

find . -name "users.ini" -print0 | while read -d $'\0' file
do
    echo "Attempting to parse ${file}"
    cfg_parser ${file}
    cfg_section_users

    echo "Attempting to create group ${group}"
    getent group ${group} 2>&1 > /dev/null || sudo groupadd ${group}

    for name in ${names[@]}
    do
        echo "Attempting to create user ${name}"
        grep "${name}" /etc/passwd 2>&1 > /dev/null || sudo adduser --system --ingroup ${group} ${name}
    done

    unset ${group}
    unset ${names}

    cfg_unset users

    echo ""
done
