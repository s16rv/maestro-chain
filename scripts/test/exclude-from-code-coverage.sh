#!/bin/sh
while read p || [ -n "$p" ] 
do  
sed -i '' "/${p//\//\\/}/d" ./coverage.out 
done < scripts/test/exclude-from-code-coverage.txt