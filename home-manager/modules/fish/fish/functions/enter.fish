
function enter
  docker ps --filter status=running --format "table {{.Image}}\t{{.Names}}\t{{.ID}}" | awk 'NR > 1 { print }' | read -z containers
  if [ -z "$containers" ];
      echo -e "No running container found"
  else
      printf $containers | fzf --reverse | awk '{ print $3 }' | read selected_container; or return
      docker exec -it "$selected_container" fish; and return
      docker exec -it "$selected_container" zsh; and return
      docker exec -it "$selected_container" bash; and return;
      docker exec -it "$selected_container" sh;
  end
end
