# Step 1: Create topology files using the selected force field (e.g., CHARMM36)
#https://jerkwin.github.io/2017/10/20/GROMACS分子动力学模拟教程-多肽-蛋白相互作用
#http://www.mdtutorials.com/gmx/complex/01_pdb2gmx.html
# renum='python /mnt/d/grx/FL_renumpdb.py'


# #step 1: PDB prepare
# pdb_reres -1 complex.pdb | pdb_delhetatm | pdb_tidy > tmp.pdb
# mv complex.pdb complexori.pdb
# $renum -i tmp.pdb -a -r > tmp1.pdb
# rm tmp.pdb

# #source /home/adsb/miniconda3/etc/profile.d/conda.sh

source /home/adsb/amber22_src/build/CMakeFiles/miniconda/install/etc/profile.d/conda.sh
conda activate /home/adsb/amber22_src/build/CMakeFiles/miniconda/install/envs/af3 #activate ab
pdbfixer complex.pdb --output complex1.pdb    
#conda /home/adsb/amber22/miniconda/bin/deactivate
mv complex1.pdb complex.pdb

echo -e "8\n0\n0\n0\n0\n0\n0\n0\n0" | gmx pdb2gmx -f complex.pdb -o complex_processed.gro -water tip3p -ignh -ter #多条链的ter

# Step 2: Define simulation box
gmx editconf -f complex_processed.gro -o complex_newbox.gro -c -d 1.4 -bt cubic

#Create a .tpr file to energy minimize the peptide structure in vacuum.
#gmx grompp -v -f $MOLMOD_DATA/mdp/01_em_vac_PME.mdp -c peptide-PBC.gro -p peptide.top -o peptide-EM-vacuum.tpr -maxwarn 1
#Minimize the structure using the .tpr file created in the previous step.
#gmx mdrun -v -deffnm peptide-EM-vacuum


# Step 3: Solvate the system with water, add ions 
# -cp: Input solute coordinate file
# -cs: Solvent coordinate file
# -o: Output solvated structure file
# -p: Topology file
gmx solvate -cp complex_newbox.gro -cs spc216.gro -o complex_solv.gro -p topol.top
gmx grompp -f ions.mdp -c complex_solv.gro -p topol.top -o ions.tpr;
echo 13 |gmx genion -s ions.tpr -o complex_solv_ions.gro -p topol.top -conc 0.15 -pname NA -nname CL -neutral

# Step 4: Create an index file to specify the groups for energy minimization
# -f: Input structure file
# -o: Output index file
echo -e "q\n" |gmx make_ndx -f complex_solv_ions.gro -o index.ndx

# Step 5: Perform energy minimization
# -f: Input molecular dynamics parameter (mdp) file
# -c: Input structure file
# -r: Input reference structure file
# -n: Input index file
# -p: Input topology file
# -o: Output trajectory file
# -e: Output energy file
# -g: Output log file
# -t: Input trajectory file to continue from
# -init_t: Initial time for input trajectory
gmx grompp -f minim.mdp -c complex_solv_ions.gro -r complex_solv.gro -p topol.top -o em.tpr
gmx mdrun -v -deffnm em;
echo 11 0 |gmx energy -f em.edr -o complex_potential.xvg;  # 如果选择8: CHARMM，此处选择11

# Step 6: Equilibrate the system (NVT and NPT)
# NVT equilibration
gmx grompp -f nvt.mdp -c em.gro -r em.gro -p topol.top -o nvt.tpr #c coordinate"（坐标）指定初始文件； r 为参考文件
gmx mdrun -deffnm nvt -nb gpu;
echo 17 0 |gmx energy -f nvt.edr -o complex_Temperature_NVT_Equilibration.xvg; # 如果选择8: CHARMM，此处选择17

# NPT equilibration
gmx grompp -f npt.mdp -c nvt.gro -r nvt.gro -t nvt.cpt -p topol.top -o npt1000.tpr 
gmx mdrun -deffnm npt1000 -nb gpu;

echo 19 0 |gmx energy -f npt1000.edr -o complex_Pressure_NPT1000_Equilibration.xvg; #如果选择8: CHARMM，此处选择19
echo 25 0 |gmx energy -f npt1000.edr -o complex_Density_NPT1000_Equilibration.xvg; #如果选择8: CHARMM，此处选择25

#重复相同的平衡模拟, 并逐步放开限制
for file in posre*.itp; do
    # Replace "1000" with "100" in each file
    sed -i 's/1000  1000  1000/100   100   100/g' "$file"
done
gmx grompp -v -f npt.mdp -c npt1000.gro -r npt1000.gro -p topol.top -o npt100.tpr
gmx mdrun -v -deffnm npt100 -nb gpu

for file in posre*.itp; do
    # Replace "1000" with "100" in each file
    sed -i 's/100   100   100/10    10    10/g' "$file"
done
gmx grompp -v -f npt.mdp -c npt100.gro -r npt100.gro -p topol.top -o npt.tpr
gmx mdrun -v -deffnm npt -nb gpu

#导出pdb文件
echo 1 |gmx trjconv -f npt.gro -o npt.pdb -s npt.tpr -n index.ndx
pdbfixer npt.pdb --output nptf.pdb
#prodigy nptf.pdb --selection A,B C --contact_list --pymol_selection >> output.txt


echo 19 0 |gmx energy -f npt.edr -o complex_Pressure_NPT_Equilibration.xvg; #如果选择8: CHARMM，此处选择19
echo 25 0 |gmx energy -f npt.edr -o complex_Density_NPT_Equilibration.xvg; #如果选择8: CHARMM，此处选择25

#由于我们引入了压力耦合, 体系的密度会发生变化. 从能量文件中提取密度数据, 方法如下:
gmx eneconv -f npt1000.edr npt100.edr npt.edr -o npt_concat.edr
echo 19 0 |gmx energy -f npt_concat.edr -o complex_Pressure_NPT_Equilibration_cc.xvg
echo 25 0 |gmx energy -f npt_concat.edr -o complex_Density_NPT_Equilibration_cc.xvg;

# Step 7: Run the production MD simulation
gmx grompp -f md.mdp -c npt.gro -t npt.cpt -p topol.top -o md_0_1.tpr
gmx mdrun -deffnm md_0_1 -nb gpu
