# Description
Quick script to spin up a network namespace alongside a bash instance. cleanup on EXIT.

# Usage
`spinup-netns.sh [-h] -i INTERFACE [-n INDEX]`

- -h: Usage
- -i: Network interface
- -n: Index for naming the namespaces so they don't collide

# Credits
Most of the script comes from:
https://gist.github.com/dpino/6c0dca1742093346461e11aa8f608a99
