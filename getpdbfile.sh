#!/bin/bash

#while read line; do
#	pdbid="${line:0:4}"
#	pdb_fetch -biounit "$pdbid" | pdb_delhetatm | pdb_tidy > "$pdbid.pdb"
#done < ~/promx/pdblist.txt


# Count the total number of lines in pdbid.txt
total_lines=$(wc -l < ~/promx/pdblist.txt)

# Loop through the lines of pdbid.txt
for (( i=1; i<=total_lines+1; i++ )); do
    # Read the current line of pdbid.txt
    line=$(sed -n "${i}p" ~/promx/pdblist.txt)
    
    # Extract the first four characters of the line
    pdbid="${line:0:4}"
    
    # Download and process the PDB file, ignoring 404 errors
    pdb_fetch "$pdbid" 2>&1 | grep -v "Error fetching structure: (404) Not Found" | pdb_delhetatm | pdb_tidy > "$pdbid.pdb"
done
