#!/bin/sh

command_available() {
  which $(echo "$1") >/dev/null 2>&1
  [ "$?" = 0 ] && echo 1 || echo ""
}

install_if_not_available() {
  command="$1"
  [ $2 ] && package="$2" || package="$command"
  if ! [ $(command_available $(echo "$command")) ]; then
    echo "Command \"$command\" is required to continue."
    sudo pacman -S $(echo "$package")
  fi
}

install_if_not_available dialog

pull_dotfiles() {
  install_if_not_available git
  git clone --bare https://github.com/ciscocarvalho/dotfiles $HOME/.dotfiles
  git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME reset --hard HEAD
}

pull_awesome_config() {
  install_if_not_available git
  git clone https://github.com/ciscocarvalho/awesome-config $HOME/.config/awesome
}

pull_nvim_config() {
  install_if_not_available git
  git clone https://github.com/ciscocarvalho/nvim-config $HOME/.config/nvim
}

pull_wallpapers() {
  install_if_not_available git
  git clone https://github.com/ciscocarvalho/wallpapers $HOME/wallpapers
}

build_nvim() {
  local NVIM_SRC_DIR=/tmp/neovim
  local NVIM_INSTALL_DIR=/tmp/new-neovim

  install_if_not_available git
  git clone https://github.com/neovim/neovim "$NVIM_SRC_DIR" --depth 1
  cd "$NVIM_SRC_DIR"
  make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="$NVIM_INSTALL_DIR" install
  echo "Neovim built and installed in $NVIM_INSTALL_DIR"
}

configure_git() {
  install_if_not_available git
  read -p "user.name: " git_user_name
  read -p "user.email: " git_user_email
  git config --global user.name "$git_user_name"
  git config --global user.email "$git_user_email"
}

bootstrap_neovim() {
  install_if_not_available nvim neovim

  font_name="codicon"
  font_initial="$(echo $font_name | grep -o '^.' | tr '[:upper:]' '[:lower:]')"
  fonts_dir="$HOME/.local/share/fonts/$font_initial"
  font_path="$fonts_dir/$font_name.ttf"
  mkdir -p "$fonts_dir"

  if ! [ -e "$font_path" ]; then
    # URL format documented on https://help.github.com/en/articles/linking-to-releases
    curl -fLo "$font_path" "https://github.com/microsoft/vscode-codicons/releases/latest/download/codicon.ttf"
  fi

  nvim +"autocmd User PlugBootstrapFinished quit"
}

authenticate_github_cli() {
  install_if_not_available gh github-cli
  gh auth login
  gh auth setup-git
}

configure_zsh() {
  install_if_not_available zsh
  chsh -s $(which zsh)
  zsh -i -c "exit"
}

install_nerdfont() {
  font_name="$1"
  font_initial="$(echo $font_name | grep -o '^.' | tr '[:upper:]' '[:lower:]')"
  fonts_dir="$HOME/.local/share/fonts/$font_initial"
  font_path="$fonts_dir/$font_name.zip"
  mkdir -p "$fonts_dir"
  curl -fLo "$font_path" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$font_name.zip"
  unzip "$font_path" -d "$fonts_dir"
  rm "$font_path"
}

install_nerdfonts() {
  install_nerdfont "JetBrainsMono"
  nerdfont_names_filepath="$1"
  message_no_nerdfont_names_filepath="$2"
  if [ -e "$nerdfont_names_filepath" ]; then
    nerdfont_names=$(cat "$nerdfont_names_filepath")
    # Remove empty and comment lines
    nerdfont_names=$(echo "$nerdfont_names" | sed "/^\s*$/d" | sed "/^\s*#.*$/d")

    for name in $(echo "$nerdfont_names" | xargs $(echo "$command")); do
      install_nerdfont "$name"
    done
  else
    echo "$message_no_packages_filepath"
  fi
}

install_packages() {
  packages_filepath="$1"
  command="$2"
  message_no_packages_filepath="$3"
  if [ -e "$packages_filepath" ]; then
    packages=$(cat "$packages_filepath")
    # Remove empty and comment lines
    packages=$(echo "$packages" | sed "/^\s*$/d" | sed "/^\s*#.*$/d")
    echo "$packages" | xargs $(echo "$command")
  else
    echo "$message_no_packages_filepath"
  fi
}

install_pacman() {
  install_packages "$HOME/Misc/package-lists/arch/pacman.txt" "sudo pacman --needed -S" "File for packages from Pacman does not exist, installation canceled."
}

install_aur_binary() {
  install_if_not_available yay
  install_packages "$HOME/Misc/package-lists/arch/aur/binary.txt" "yay --needed -S" "File for binary packages from AUR does not exist, installation canceled."
}

install_aur_non_binary() {
  install_if_not_available yay
  install_packages "$HOME/Misc/package-lists/arch/aur/non_binary.txt" "yay --needed -S" "File for non-binary packages from AUR does not exist, installation canceled."
}

install_pip() {
  install_if_not_available python-pip
  install_packages "$HOME/Misc/package-lists/pip.txt" "pip3 install" "File for packages from PIP does not exist, installation canceled."
}

install_npm() {
  install_if_not_available npm
  install_packages "$HOME/Misc/package-lists/npm.txt" "sudo npm install -g" "File for packages from NPM does not exist, installation canceled."
}

uninstall_gnome_keyring() {
  sudo pacman -Rns gnome-keyring
}

ask_box() { dialog --colors --title "$1" --yes-label "$2" --no-label "$3" --yesno "$4" 0 0; }

ask_box "Bootstrap Script" "Continue" "Return" "This script is going to bootstrap Francisco Carvalho's system configuration.\n\nIt will assume it is running on a Manjaro system."
! [ "$?" = 0 ] && exit

ask_box "Be sure you have your keyboard layout properly set before continuing" "Continue" "Return" 'You can see a list of keyboard layouts and models by running "man xkeyboard-config" on the command-line (without quotes), then you can set a keyboard layout with "setxkbmap <layout>". For example, to set your keyboard layout to "us", use "setxkbmap us".'
! [ "$?" = 0 ] && exit

ask_box "Configure Git?" "Yes" "No" "Requires global user.name and user.email used for Git."
[ "$?" = 0 ] && opt_configure_git=1

ask_box "Authenticate Github CLI?" "Yes" "No" "Requires a web browser or an authentication token."
[ "$?" = 0 ] && opt_authenticate_github_cli=1

ask_box "Pull dotfiles repository?" "Yes" "No" "If some/all of those files already exist, they will be overwritten.\n\nFiles in $HOME/.config/nvim/ are required for bootstrapping Neovim.\n\nFiles in $HOME/Misc/package-lists/arch/ are required for installing packages from Pacman and/or AUR.\n\nRequires Github username and password/authentication token."
[ "$?" = 0 ] && opt_pull_dotfiles=1

ask_box "Pull awesome config?" "Yes" "No" "If some/all of those files already exist, they will be overwritten."
[ "$?" = 0 ] && opt_pull_awesome_config=1

ask_box "Pull nvim config?" "Yes" "No" "If some/all of those files already exist, they will be overwritten."
[ "$?" = 0 ] && opt_pull_nvim_config=1

ask_box "Pull wallpapers repository?" "Yes" "No" "If some/all of those files already exist, they will be overwritten."
[ "$?" = 0 ] && opt_pull_wallpapers=1

ask_box "Build neovim from source?" "Yes" "No" ""
[ "$?" = 0 ] && opt_build_nvim=1

ask_box "Bootstrap Neovim?" "Yes" "No" "If it was already bootstrapped, you will have to quit manually."
[ "$?" = 0 ] && opt_bootstrap_neovim=1

ask_box "Configure zsh?" "Yes" "No" ""
[ "$?" = 0 ] && opt_configure_zsh=1

ask_box "Install nerdfonts?" "Yes" "No" ""
[ "$?" = 0 ] && opt_install_nerdfonts=1

ask_box "Install Pacman packages?" "Yes" "No" ""
[ "$?" = 0 ] && opt_install_pacman=1

ask_box "Install AUR packages?" "Yes" "No" ""
[ "$?" = 0 ] && {
  opt_install_aur_binary=1

  ask_box "Also install non-binary AUR packages?" "Yes" "No" "These can take a really long time to be installed and might fail, because they are compiled from source."
  [ "$?" = 0 ] && opt_install_aur_non_binary=1
}

ask_box "Install PIP packages?" "Yes" "No" ""
[ "$?" = 0 ] && opt_install_pip=1

ask_box "Install NPM packages?" "Yes" "No" ""
[ "$?" = 0 ] && opt_install_npm=1

ask_box "Uninstall gnome keyring?" "Yes" "No" "Keyring is a linux security feature, but gnome keyring makes an annoying popup appear everytime one opens up a browser if they use automatic login on their system.\n\ngnome keyring is installed by default in some linux distros."
[ "$?" = 0 ] && opt_uninstall_gnome_keyring=1

opts="configure_git authenticate_github_cli pull_dotfiles pull_awesome_config pull_nvim_config pull_wallpapers build_nvim bootstrap_neovim configure_zsh install_nerdfonts install_pacman install_aur_binary install_aur_non_binary install_pip install_npm uninstall_gnome_keyring"
opts_info=""

for opt_name in $opts; do
  opt_value=$(eval echo "$""opt_$opt_name")
  if [ $opt_value ]; then
    opts_info=$(echo "$opts_info
$opt_name = TRUE")
  else
    opts_info=$(echo "$opts_info
$opt_name = FALSE")
  fi
done

ask_box "Continue with these options?" "Continue" "Return" "$opts_info"
! [ "$?" = 0 ] && exit

clear

for opt_name in $opts; do
  opt_value=$(eval echo "$""opt_$opt_name")
  if [ $opt_value ]; then
    opt_func() { eval $opt_name; }
    opt_func
  fi
done
