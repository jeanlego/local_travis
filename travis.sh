#!/bin/bash
declare -a VAR=(
	"$1"
	"$2"
	"$3"
	"$4"
)

declare -a TRAVIS_LANG=(
	"default"
	"android"
	"erlang"
	"haskell"
	"perl"
	"go"
	"jvm"
	"node_js"
	"php"
	"python"
	"ruby"
)
declare -a TRAVIS_IMG=(
	"travisci/ci-garnet:packer-1512502276-986baf0"
	"travisci/ci-amethyst:packer-1512508255-986baf0"
	"travisci/ci-amethyst:packer-1512508255-986baf0"
	"travisci/ci-amethyst:packer-1512508255-986baf0"
	"travisci/ci-amethyst:packer-1512508255-986baf0"
	"travisci/ci-garnet:packer-1512502276-986baf0"
	"travisci/ci-garnet:packer-1512502276-986baf0"
	"travisci/ci-garnet:packer-1512502276-986baf0"
	"travisci/ci-garnet:packer-1512502276-986baf0"
	"travisci/ci-garnet:packer-1512502276-986baf0"
	"travisci/ci-garnet:packer-1512502276-986baf0"
)
TRAVIS_LEN=${#TRAVIS_IMG[@]}

#set parent directory and init
TRAVIS_ROOT=$([ "$USER" == "root" ] && echo /$USER || echo /home/$USER)
TRAVIS_DIR="${TRAVIS_ROOT}/.travisci"
PROJECT_TRACKER="${TRAVIS_DIR}/.working_project"

BUILD_HEADER="travisci"
BUILD_ID="${RANDOM}"

WORKING_PROJECT=$(cat ${PROJECT_TRACKER})
PROGRAM_LANG="ERROR"
PROGRAM_IMG="ERROR"

# ~/.travisci
# 	| .working_project			(specifies wich project directory we are working in)
# 	| [project common name]1
# 		| .lang
# 		| ...
# 	| [project common name]2
# 	| ...

function print_error(){
	err_msg=$1
	echo -e "\e[91m${err_msg}\e[39m"
}

function declare_cmd(){
	cmd=$1
	comment=$2
	echo -e "	\e[7m${cmd}\e[27m ${comment}"
}

function error_cmd(){
	err_msg=$1
	cmd=$2
	comment=$3
	print_error "${err_msg}"
	[ "${cmd}" != "" ] && echo -e "Usage is: \e[7m${cmd}\e[27m ${comment}"
	exit 1
}

function print_help(){
	echo "This is a TravisCI mockup"
	echo "Usage:"
	declare_cmd "init <Common Name> <Language*>" "*if language is not declared, we set to default"
	declare_cmd "project <Common Name>" ""
}

function collapse_project() {
	project=$1
	if [ -f ${TRAVIS_DIR}/projects/${project} ]; then
		rm -Rf ${TRAVIS_DIR}/projects/${project}
	fi
}

function switch_project(){
	project=$1
	[ ! -e "${TRAVIS_DIR}/projects/${project}" ] && print_error "Project ${TRAVIS_DIR}/projects/${project} does not exits" && exit 1
	echo ${project} > ${PROJECT_TRACKER}
	WORKING_PROJECT=${project}

	if [ -e "${TRAVIS_DIR}/projects/${WORKING_PROJECT}/.lang" ]; then
		PROGRAM_LANG=$(cat ${TRAVIS_DIR}/projects/${WORKING_PROJECT}/.lang)
	fi

	count=0
	for i in ${TRAVIS_LANG[@]}; do
		case ${PROGRAM_LANG} in
			$i)
				PROGRAM_IMG=${TRAVIS_IMG[count]}
				break
			;;
		esac
		count=$((count+1))
	done

	if [ ${PROGRAM_IMG} == "ERROR" ]; then
		print_error "ERROR"
		echo "Language ${PROGRAM_LANG} is not a valid language to init"
		echo "the following are allowed:"
		echo ${TRAVIS_LANG[@]}
		PROGRAM_LANG="ERROR"
	fi
}

#first install_travis
if [ ! -f ${PROJECT_TRACKER} ]; then
	case "_${VAR[0]}" in
		_install)
			mkdir -p ${TRAVIS_DIR}/projects
			echo "ERROR" > ${PROJECT_TRACKER}
			#pull travis script builder
			git clone https://github.com/travis-ci/travis-build.git ${TRAVIS_DIR}/travis-build

			#pull both travis images
			docker pull ${TRAVIS_IMG[0]}
			docker pull ${TRAVIS_IMG[1]}
			exit 0
		;;
		*)
			print_error "You Need to install TravisCi Mockup First"
			echo "please use 'install'"
			echo "you can set the target instalation directory manually by setting export TRAVIS_ROOT=<Target Directory>"
			echo "the current one is set to be ${TRAVIS_ROOT}"
			exit 1
		;;
	esac
fi

#deal with empties and help
# also init working project language
churn_on=0
case "_${VAR[0]}" in
	_install)
		print_error "TravisCI is already installed @${TRAVIS_DIR}"
	;;
	_);& _help)
		print_help
	;;
	_init)
		input_travis=${VAR[1]}
		src_path=${input_travis%/*}
		([ ! -f ${src_path}/.travis.yml ] || [ "_${VAR[2]}" == "_" ]) && error_cmd "ERROR" "init </full/path/to/travis.yml> <Common Name> <Language*>" "*if language is not declared, we set to default"
		[ -e ${TRAVIS_DIR}/projects/${VAR[2]} ] && error_cmd "ERROR Project ${VAR[2]} already exits"

		[ "_${VAR[3]}" == "_" ] && VAR[3]="default"

		mkdir -p ${TRAVIS_DIR}/projects/${VAR[2]}
		echo ${VAR[3]} > ${TRAVIS_DIR}/projects/${VAR[2]}/.lang
		ln -s ${src_path} ${TRAVIS_DIR}/projects/${VAR[2]}/src

		switch_project ${VAR[2]}
		[ "${PROGRAM_LANG}" == "ERROR" ] 	&& collapse_project ${VAR[2]} && exit 1

		bundle exec ${TRAVIS_DIR}/travis-build/script/compile < ${TRAVIS_DIR}/projects/${WORKING_PROJECT}/src/.travis.yml > ${TRAVIS_DIR}/projects/${WORKING_PROJECT}/do_not_use.sh

		echo "Project ${WORKING_PROJECT} as been initialized"
	;;
	_project)
		[ "_${VAR[1]}" == "_" ] 		&& error_cmd "ERROR" "project <Common Name>" ""
		[ "_${VAR[2]}" != "_" ] 		&& error_cmd "ERROR" "project <Common Name>" ""
		switch_project ${VAR[1]}
		[ "${PROGRAM_LANG}" == "ERROR" ] && exit 1
		echo "Switched to ${WORKING_PROJECT}"
	;;
	_ls)
		[ "_${VAR[1]}" != "_" ] 		&& error_cmd "ERROR" "ls" ""
		echo "Project list"
		echo "================="
		ls ${TRAVIS_DIR}/projects
		echo ""
		echo "Running Containers"
		echo "================="
		docker ps -a --filter name=${BUILD_HEADER} --format {{.Names}}
	;;
	_ps)
		[ "${VAR[1]}" == "_" ] && error_cmd "ERROR" "ps <Common Name>" ""
		[ ! -f ${TRAVIS_DIR}/projects/${VAR[1]}/.lang ] && error_cmd "ERROR" "Project ${VAR[1]} is not valid" ""
		echo "Running Containers for ${VAR[1]}"
		echo "================="
		docker ps -a --filter name=${BUILD_HEADER}-${VAR[1]} --format {{.Names}}
	;;
	_clean)
		[ "${VAR[1]}" == "_" ] && error_cmd "ERROR" "clean <Common Name>" ""
		[ ! -e ${TRAVIS_DIR}/projects/${VAR[1]} ] && error_cmd "ERROR" "Project ${VAR[1]} is not valid" ""

		CONTAINER_LIST=$(docker ps -a --filter name=${BUILD_HEADER}-${VAR[1]} --format {{.Names}})
		echo ${CONTAINER_LIST}
		docker stop ${CONTAINER_LIST}
		docker rm ${CONTAINER_LIST}
		rm -Rf ${TRAVIS_DIR}/projects/${VAR[1]}
		echo "Cleaned Project ${VAR[1]}"
	;;
	*)
		churn_on=1
	;;
esac
#exit point if one of the command above ran
[ "${churn_on}" == "0" ]				&& exit 0

[ "${WORKING_PROJECT}" == "ERROR" ] 	&& print_error "ERROR you have no initialized project set" && print_help && exit 1
switch_project ${WORKING_PROJECT}
[ "${PROGRAM_LANG}" == "ERROR" ] 		&& print_error "ERROR unable to process ${VAR[0]}" && print_help && exit 1

case ${VAR[0]} in
	ps)
		[ "${WORKING_PROJECT}" == "ERROR" ]	&& print_error "ERROR you have no initialized project set, you can switch to one using 'project <common name>'" && exit 1
		echo "Running Containers for ${WORKING_PROJECT}"
		echo "================="
		docker ps -a --filter name=${BUILD_HEADER}-${WORKING_PROJECT} --format {{.Names}}
	;;
	*)
		print_error "ERROR unable to process <${VAR[0]}> as it is an invalid command"
		print_help
		exit 1
	;;
	start)
	;;
	stop)
	;;
	remove)
	;;
esac
