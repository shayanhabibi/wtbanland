# Welcome to Ban Land

A repo of my utility libraries that aren't worth much; however, I find myself constantly requiring to use them so here they are.

## Atomics

Have made small changes. Can do arithmetic without the atomic having to be an Integer type. Can access raw values. Aliases for memory orders that are shorter.

## CacheLine

Yet to be completed (?linux?). Just a simple procedure to determine the L1 cacheline size of the cpu.

## Futex

Futexes; cheap bois.

Have implemented basic behaviour for macosx using ulock, windows using waitonaddress, linux using futex.

They each have their own behaviours.

## Memalloc

The aligned allocation procedures that were not exported from the nim library. Have been adjusted to suit my own needs.

## Tagptr

I pretty consistently use algorithms that have aligned pointers which have flags/tags/indexes superimposed on them. This is a library just to make that easier for me to work with.