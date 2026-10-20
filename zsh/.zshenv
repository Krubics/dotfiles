# ~/.zshenv
typeset -U path PATH

path=(
  "$HOME/.local/bin"
  "$HOME/.cargo/bin"
  "$HOME/.nix-profile/bin"
  $path
)
export PATH

source /home/krubics/.config/meridian/.env
# For Meridian (Claude Code SDK Proxy)
export ANTHROPIC_API_KEY=x
export ANTHROPIC_BASE_URL=http://127.0.0.1:3456

#QT Theming
export QT_QPA_PLATFORMTHEME=qt6ct
export QT_STYLE_OVERRIDE=Fusion

#Envs
source $HOME/.env

