# bash (and zsh via bashcompinit) completion for atticus
_atticus() {
  local cur prev words
  cur="${COMP_WORDS[COMP_CWORD]}"; prev="${COMP_WORDS[COMP_CWORD-1]}"
  local cmds="setup init go update doctor remove add start status resume bench ci migrate help version evidence verify scorecard metrics console portfolio contract sla wiki-lint knowledge-index integrity decide completion"
  local roles="developer architect qa product-owner devops-sre tech-lead scrum-master designer release-manager"
  local agents="claude-code cursor copilot windsurf cline aider gemini antigravity tabnine agents-md"
  case "$prev" in
    --agent) COMPREPLY=($(compgen -W "$agents" -- "$cur")); return ;;
    --role|add) COMPREPLY=($(compgen -W "$roles" -- "$cur")); return ;;
    --profile) COMPREPLY=($(compgen -W "feature bugfix poc security infra data migration" -- "$cur")); return ;;
    --shell) COMPREPLY=($(compgen -W "zsh bash fish pwsh" -- "$cur")); return ;;
    --tier) COMPREPLY=($(compgen -W "1 2 3" -- "$cur")); return ;;
    evidence) COMPREPLY=($(compgen -W "run list summary compact" -- "$cur")); return ;;
    go) COMPREPLY=($(compgen -d -- "$cur")); return ;;
  esac
  if [ "$COMP_CWORD" -eq 1 ]; then COMPREPLY=($(compgen -W "$cmds" -- "$cur")); return; fi
  case "${COMP_WORDS[1]}" in
    init) COMPREPLY=($(compgen -W "--agent --role --tier --hub --ci --decisions --track-root --no-hooks --track-only -y -v" -- "$cur")) ;;
    setup) COMPREPLY=($(compgen -W "--shell --global --name --undo --bin -y" -- "$cur")) ;;
    update) COMPREPLY=($(compgen -W "--self --project" -- "$cur")) ;;
    doctor) COMPREPLY=($(compgen -W "--fix" -- "$cur")) ;;
    start) COMPREPLY=($(compgen -W "--profile --tier --request --force" -- "$cur")) ;;
  esac
}
complete -F _atticus atticus
