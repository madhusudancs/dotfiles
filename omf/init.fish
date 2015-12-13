eval (dircolors -c $HOME/.dircolors/dircolors.ansi-dark | sed 's/>&\/dev\/null$//')

set -Ux EDITOR vim

set -gx GOROOT $HOME/go
set -gx GOPATH $HOME/godev

set PATH $HOME/.local/bin $GOPATH/bin $GOROOT/bin $PATH

. $HOME/.config/omf/virtual.fish
