if ! tmux ls | grep -sq usiwatch; then
    tmux -2u new-session -d -s "usiwatch" -n "flask" "systemctl start mongod && while true; do run/Flask.sh; echo; read -p \" >> Enter to restart! (Ctrl+C to quit)\"; done;"
    tmux new-window -t "usiwatch" -n "elm" "run/Elm.sh"
    tmux new-window -t "usiwatch" -n "stop" "echo Ctrl+b d to detach; read -p \" >> Press enter to quit\"; tmux ls | grep -sq daycare && tmux kill-session -t daycare && systemctl stop mongod"
fi
tmux att -t "usiwatch"