#!/bin/sh
# file: entrypoint.sh

# Now, execute the main application in the foreground.
# It will receive any arguments passed to the container.
exec /iscsiplugin "$@"
