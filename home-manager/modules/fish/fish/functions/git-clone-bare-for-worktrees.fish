function git-clone-bare-for-worktrees --argument url destination
    set oldDir (pwd)
    if test -d $destination
        echo "$destination already exists"
        return 1
    end
    mkdir $destination
    cd $destination
    git clone --bare $url .bare
    echo "gitdir: ./.bare" > .git
    git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    cd $oldDir
end
