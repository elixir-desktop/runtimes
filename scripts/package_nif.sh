#!/bin/bash

if [ -d "_build/prod/lib/$1" ]; then
    exec zip -rjx "*.empty" - "_build/prod/lib/$1/priv/"
fi

exec zip -rjx "*.empty" - priv/
