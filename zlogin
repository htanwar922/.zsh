#!/bin/zsh

# Import all .zsh files in ~/.zsh
for file in ~/.zsh/*.zsh; do
    [[ ${file:t} == custom*.zsh ]] && continue
    source $file
done

for file in ~/.zsh/custom*.zsh; do
    source $file
done
