#!/bin/zsh

function append-to-prompt() {
    export PROMPT=$(echo $PROMPT | sed "s/]/] $@/")
}

