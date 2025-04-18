#!/bin/zsh

function prompt-suffix() {
    # export PROMPT=$(echo $PROMPT | sed "s/]/] $@/")
    export PROMPT_SUFFIX=" $@"
}

