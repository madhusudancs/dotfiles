# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=10000000000
HISTFILESIZE=20000000000
HISTTIMEFORMAT="%F %T"
shopt -s cmdhist

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

eval `dircolors $HOME/ls-colors-solarized/dircolors`

function work {
  cd /media/python/iitb/workshops/
}

function hs {
  cd /media/professional/profiles-resumes-docs/higher_studies/
}

function mel {
  cd /media/python/workspace/melange/
}

function mpy {
  cd /media/python
}

function wos {
  cd /media/python/workspace/
}

function sshos {
  ssh madhusudancs@88.198.40.10
}

function sermel {
  cd /media/python/workspace/melange
  command=python
  if [ -n $1 ]; then
    command=$command$1
  fi
  `$command ./thirdparty/google_appengine/dev_appserver.py --use_sqlite --datastore_path=/media/python/melangedatafiles/devdata.sqlite --blobstore_path=/media/python/dev_appserver.blobstore --port=8000 --enable_sendmail --show_mail_body --allow_skipped_files --skip_sdk_update_check --default_partition "" --high_replication build`
}

function e {
  gvim
}

function nme {
  $@;
  old_status=$?;
  if [ $old_status -eq 0 ]; then
    notify-send "Commands successfully executed!";
  else
    notify-send "Commands exited with status $old_status";
  fi
  return $old_status;
}

function g {
  git $@;
}

function hyd {
  export JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64
  export PATH=$PATH:/media/python/workspace/hyracks-read-only/hyracks/hyracks-server/target/hyracks-server-0.1.9-SNAPSHOT-binary-assembly/bin:/media/python/workspace/hyracks-read-only/hyracks/hyracks-cli/target/hyracks-cli-0.1.9-SNAPSHOT-binary-assembly/bin;
  export JAVA_OPTS="-Xmx1024m";
}

function bhyr {
  cd /media/python/hyracks-git
  mvn package install -DskipTests=true
}

function bast {
  cd /media/python/asterixdb-megamerge-git/asterix-dist/target/asterix-dist-0.0.4-SNAPSHOT-binary-assembly
  ./stopasterix.sh
  bhyr
  cd /media/python/asterixdb-megamerge-git
  mvn package -DskipTests=true
  cd /media/python/asterixdb-megamerge-git/asterix-dist/target/asterix-dist-0.0.4-SNAPSHOT-binary-assembly
  ./startasterix.sh 2
  cd /media/python/asterixdb-megamerge-git
}

export GOROOT=$HOME/go
export CGO_CFLAGS="`llvm-config --cflags`"
export CGO_LDFLAGS="`llvm-config --ldflags` -W1,L`llvm-config --libdir` -lLLVM-`llvm-config --version`"

export PATH=$HOME/.local/bin:/var/lib/gems/1.9.1/bin:$HOME/installs/node/bin:/media/python/workspace/pl241-mcs:/media/python/yComp-1.3.16:$GOROOT/bin:/home/madhu/akmaxsat_1.1:$HOME/.rvm/bin:/media/python/llvmbuild/Debug+Asserts/bin:$PATH

export EDITOR=vim

export PYTHONPATH=$PYTHONPATH:/home/madhu/.local/lib/python2.6/site-packages/:/home/madhu/.local/lib/python2.7/site-packages/:/home/madhu/.local/lib/:/media/python/workspace/disco/lib:/media/python/workspace/pl241-mcs

export LD_LIBRARY_PATH=/home/madhu/.local/lib/:/usr/local/lib/

export YCOMP=/media/python/yComp-1.3.16/

export jsmath_path=/usr/share/jsmath

# Ruby Vitual Machine
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
[[ -r $rvm_path/scripts/completion ]] && . $rvm_path/scripts/completion


function parse_git_dirty {
  [[ $(git status 2> /dev/null | tail -n1) != "nothing to commit (working directory clean)" ]] && echo " *"
}

function parse_git_branch {
  git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e "s/* \(.*\)/[\1$(parse_git_dirty)]/"
}

#export PS1='\[\e[1;32m\]\w\[\e[0m\]$(__git_ps1 " (\[\e[0;32m\]%s\[\e[0m\]\[\e[1;33m\]$(parse_git_dirty)\[\e[0m\])")\[\e[0;32m\]$\[\e[0m\] '

source $HOME/.git-prompt
source $HOME/.kpumukprompt

export DEBFULLNAME="Madhusudan C.S."
export DEBEMAIL="madhusudancs@gmail.com"

# Core file limit
ulimit -c 750000

