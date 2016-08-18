#!/bin/bash

. app/colors.sh


# run as root only
if [[ $EUID -ne 0 ]] ; then
    run_error "This script must be run with root access"
    exit 1
fi
if [ -z ${ROOT+x} ];  then show_red "Error" "ROOT system variable is not set! Check config.sh";  exit 1; fi
if [ -z ${CACHE+x} ]; then show_red "Error" "CACHE system variable is not set! Check config.sh"; exit 1; fi
if [ -z ${BUILD+x} ]; then show_red "Error" "BUILD system variable is not set! Check config.sh"; exit 1; fi


function download_nginx_module() { # OK
  [ $# -eq 0 ] && { run_error "Usage: install_nginx_module <module>"; exit; }  
  local WORKDIR="${CACHE}nginx_modules/"
  local MODULE=${1}
  
  [ -d "$WORKDIR" ] || mkdir $WORKDIR
  cd ${WORKDIR}

  if [ ${NGINX_MODULES[${MODULE}]} ] ; then
    show_blue_bg "Download" "${MODULE}"
    
    if [ -s "${MODULE}.zip" ] ; then
      show_yellow "Cache" "found ${MODULE}.zip. Using from cache" 
      else 
        wget -q --no-check-certificate ${NGINX_MODULES[${MODULE}]} -O "${MODULE}.zip"
    fi
    if [ -s "${MODULE}.zip" ] ; then
      run_ok
    else 
      run_error "Could not fetch ${MODULE}.zip from ${NGINX_MODULES[${MODULE}]}"
    fi
  else 
    run_error "${MODULE} module does not have a download route. Add in lib/nginx_modules.sh or remove ${MODULE} from NGINX_INSTALL_MODULES"
  fi
}

function configure_nginx_module() {
  # get them from cache and put them in work
  [ $# -eq 0 ] && { run_error "Usage: configure_nginx_module <module_name>"; exit; }  
  local WORKDIR="${ROOT}nginx_modules/"
  local CACHEDIR="${CACHE}nginx_modules/"  
  local MODULE=${1}
  
  rm -rf ${WORKDIR}${MODULE}
  [ -d "$WORKDIR${MODULE}" ] || mkdir -p ${WORKDIR}${MODULE}
  [ -d "${CACHEDIR}${MODULE}.zip" ] || download_nginx_module ${MODULE}
  
  show_blue_bg "Unpack" "${MODULE}"

  cd ${WORKDIR}
  unzip -q -o "${CACHEDIR}${MODULE}.zip" -d ${WORKDIR}${MODULE}
  local ROOT_NAME=`find ${MODULE}/* | head -1`
  
  if [ -z ${ROOT_NAME+x} ]; then 
      show_red "Error" "${MODULE} root name is not a dir. Check ${CACHEDIR}${MODULE}.zip"; exit 1; 
    else
      cp -RP ${WORKDIR}${ROOT_NAME}/* ${WORKDIR}${MODULE}
      rm -rf ${WORKDIR}${ROOT_NAME}
      run_ok
  fi
}

## not tested
## not tested
## not tested
## not tested
function configure_nginx_patches() {
  [ $# -eq 0 ] && { run_error "Usage: configure_nginx_patches <module_name>"; exit; }  
  local WORKDIR="${ROOT}nginx_patches/"
  local MODULE=${1}
  
  [ -d "$WORKDIR${MODULE}" ] || mkdir $WORKDIR${MODULE}
  cd ${WORKDIR}

    for file in ${WORKDIR}/* ; do
        run_compile "applying patch $(basename $file)"
        patch -p1 < $file
    done

  run_ok
}

function make_nginx() {
  [ $# -eq 0 ] && { run_error "Usage: make_nginx <default_configuration_params>"; exit; } 

  # Set: vars
  local MAIN_DIR="nginx"
  local WORKDIR="${BUILD}${MAIN_DIR}/"  
  local MODULES="${ROOT}nginx_modules/"
  local FILENAME="nginx-${1}.tar.gz"
  local CONFIGURE_PARAMS=""
  local DEFAULT_PARAMS=${1}
  local MODULE_PARAMS=""

  # clean
  rm -rf ${WORKDIR} && mkdir -p ${WORKDIR}
  # copy fresh nginx source
  cp -PR ${CACHE}${MAIN_DIR} ${BUILD}

  if [ -f "${WORKDIR}configure" ] ; then
      show_green "Found nginx"
    else
      run_error "Cannot find nginx source code in ${WORKDIR}"
      exit 1
  fi 
  cd ${WORKDIR}

  # ./configure all modules 
  for file in ${MODULES}* ; do
      if [ -d "$file" ]
      then
          if [ -f "$file/config" ] ; then 
              local MODULE=$(basename $file)
              # Check: if module has extra things to run and run it(ex: pagespeed)
              # SH: takes 1 param:: path to install to
              if [ -f "${SCRIPT_PATH}app/module_deps/${MODULE}-install.sh" ]; then
                  . ${SCRIPT_PATH}app/module_deps/${MODULE}-install.sh $file/
              fi  
              # Set configure parameters
              CONFIGURE_PARAMS="${CONFIGURE_PARAMS} --add-module=${MODULES}${MODULE}"
              MODULE_PARAMS=""
              else
                  show_red "Error" "${MODULE} is not a nginx compilable module. Maybe just a script?"
          fi
      fi 
    done

  cd ${WORKDIR}
  # make && make install
  ./configure ${DEFAULT_PARAMS}${CONFIGURE_PARAMS}
  make && make install

  run_ok "END"
}


function clean() {
  rm -Rf "${ROOT}brotli"
  rm -Rf "${ROOT}luajit"
  rm -Rf "${ROOT}nginx"
  rm -Rf "${ROOT}nginx_modules"
  rm -Rf "${ROOT}nginx.tar.gz"
}