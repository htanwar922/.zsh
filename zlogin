#!/bin/zsh

# Import all .zsh files in ~/.zsh
for file in ~/.zsh/*.zsh; do
    source $file
done

