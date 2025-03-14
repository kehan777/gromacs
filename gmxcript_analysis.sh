#!/bin/bash
# Step 8: Analyze the trajectory
#pseudo atom；show lines;hide water
#https://github.com/haddocking/MD-scoring/blob/main/gmx_scripts/run_analysis.sh

renum='python renumber_bychain.py'
#calc_d='python start_d.py'

# index 生成?
#echo 1 |gmx trjconv -f npt.gro -o npt.pdb -s npt.tpr -n index.ndx

#gmx select -f npt.gro -s npt.tpr -select "mol 1" "mol 2 or mol 3" -on mols2.ndx
#gmx select -f npt.gro -s npt.tpr -select "mol 1 and resid 10 and name CA" -on mols3.ndx

read -r -p "Please set center/lig/rec group to Index file, ok ?  (y/n)" input2
if [ "$input2" == "y" ] || [ "$input2" == "Y" ]; then
	gmx check -f md_0_1.xtc &> tmp_info.txt
	t0=$(grep 'Box' ./tmp_info.txt| awk '{print $2 -1 }') #帧数
	st=$((t0 *10 / 2))
	et=$((t0 *10))
	echo $t0
	echo $st
	echo $et
	echo -e "17\n0" | gmx trjconv -s md_0_1.tpr -f md_0_1.xtc -n index.ndx -o md_0_1_noPBC.xtc -pbc mol -center #-b $st -e $et #周期性边界，index 添加 center  -b 20000 -e 30000
	e0=$((et /10 - st / 10 -1))
	echo $e0


	source /home/adsb/amber22_src/build/CMakeFiles/miniconda/install/etc/profile.d/conda.sh
	for i in {0..20}; do
	    e=$((t0 *20  - 20 * i *20))
	    filename="complex_e$i.pdb"
	    echo 1 | gmx trjconv -s md_0_1.tpr -f md_0_1_noPBC.xtc -o "$filename" -dump $e 
	done

	conda activate af3
	for i in {0..20}; do
	    e=$((t0  - 20 * i))
	    filename="complex_e$i.pdb"
	    tmppdb="tmp.pdb"
	    pdbfixer "$filename" --output "$tmppdb"
	    $renum -i "$tmppdb" -a -r > "${filename%.pdb}f.pdb"
	    prodigy "${filename%.pdb}f.pdb" --selection A,B C --contact_list --pymol_selection    
	    prodigy "${filename%.pdb}f.pdb" --selection A,B C --contact_list --pymol_selection >> output.txt
	    echo $e >> output.txt
	done
	conda deactivate

	echo -e "4\n4" | gmx rms -s md_0_1.tpr -f md_0_1_noPBC.xtc -o complex_RMSD_Backbone.xvg -tu ns
	echo -e "4\n4" | gmx rms -s em.tpr -f md_0_1_noPBC.xtc -o complex_RMSD_Xtal_Backbone.xvg -tu ns


	echo 1 |gmx rmsf -f md_0_1_noPBC.xtc -s md_0_1.tpr -o complex_RMSF_atom.xvg
	echo 1 |gmx rmsf -f md_0_1_noPBC.xtc -s md_0_1.tpr -o complex_RMSF_res.xvg -ox average.pdb -oq bfactors-res.pdb -res
	echo 3 |gmx rmsf -f md_0_1_noPBC.xtc -s md_0_1.tpr -o complex_RMSFa_res.xvg -ox aaverage.pdb -oq bfactorsa-res.pdb -res
	#pymol average.pdb bfactors-res.pdb
	#spectrum b, selection=bfactors-res

	echo 1 |gmx gyrate -s md_0_1.tpr -f md_0_1_noPBC.xtc -o complex_Radius_of_gyration.xvg
	echo 3 |gmx gyrate -s md_0_1.tpr -f md_0_1_noPBC.xtc -o complex_Radius_of_gyration_backbone.xvg


	echo 12 0 |gmx energy -f md_0_1.edr -o md_0_1_potential.xvg # 蛋白势能变化
	potential_min_time=$(awk 'NR>1{print $1,$2}' md_0_1_potential.xvg | sort -k2 -n | head -n 1 | awk '{print $1}') # 蛋白能量最小化的那一帧时间
	echo 1 | gmx trjconv -s md_0_1.tpr -f md_0_1_noPBC.xtc -o energy_min.pdb -dump $potential_min_time # 蛋白能量最小化的那一帧结构

	echo 1 |gmx sasa -f md_0_1_noPBC.xtc -s md_0_1.tpr -n index.ndx -o sasap.xvg -oa atomic-sasp.xvg -or residue-sasp.xvg  #protein sasa
	echo 18 |gmx sasa -f md_0_1_noPBC.xtc -s md_0_1.tpr -n index.ndx -o sasal.xvg -oa atomic-sasl.xvg -or residue-sasl.xvg  #lig sasa
	echo 19 |gmx sasa -f md_0_1_noPBC.xtc -s md_0_1.tpr -n index.ndx -o sasar.xvg -oa atomic-sasr.xvg -or residue-sasr.xvg  #rec sasa
	paste sasap.xvg sasal.xvg sasar.xvg | awk '{print $1, ( $4 + $6 -$2)}' > bsa.xvg #包埋可接触表面积


	gmx select -s md_0_1.tpr -n index.ndx -select "group 18 and name N C CA O" "group 19 and name N C CA O"  -on index2.ndx #molecules backbone l-rmsd index
	echo 0 1 |gmx rms -s md_0_1.tpr -f md_0_1_noPBC.xtc -n index2.ndx -tu ns -o l-rmsd.xvg #l-rmsd
	gmx select -s md_0_1.tpr -n index.ndx -select "((group 18 and within 1 of group 19) and name N C CA O) or ((group 19 and within 1 of group 18) and name N C CA O)" -on nat_contact.ndx -oi nat_contact.dat -b 0 -e 0 ##interface irmsd
	gmx rms -s md_0_1.tpr -f md_0_1_noPBC.xtc -o irmsd.xvg -tu ns -n nat_contact.ndx #interface irmsd

	#https://manual.gromacs.org/current/onlinehelp/gmx-hbond.html
	#echo 18 19 |gmx hbond -s md_0_1.tpr -f md_0_1_noPBC.xtc -n index.ndx -g hbond_ref.log -hbn hbindex_ref.ndx -contact -r2 0.5 -num hbond_num1.xvg #氢键距离及数量
	echo "18\n19" gmx hbond -s md_0_1.tpr -f md_0_1_noPBC.xtc -n index.ndx -num hbnum.xvg -dist hbdist.xvg -dan hbdan.xvg #-b 150000 -e 200000

	#echo -e "1\n13" | gmx hbond -s md_0_1.tpr -f md_0_1_noPBC.xtc -n index.ndx -num hbond_num.xvg #氢键距离及数量 protein,SOL	

	echo -e "4\n4" | gmx covar -f md_0_1_noPBC.xtc -s md_0_1.tpr -o eigenval.xvg -v eigenvect.trr -xpma covara.xpm -dt 10 # 主成分分析


	gmx rama -s md_0_1.tpr -f md_0_1_noPBC.xtc -o rama.xvg -dt 10 #rama 氏图
	mv rama.xvg rama.xYvg
	
	gmx distance -s md_0_1.tpr -f md_0_1_noPBC.xtc -n index.ndx -select 'com of group 18 plus com of group 19' -oall -tu ns -pbc yes &>> tmp_info.txt

	#gmx distance Analyzed 2001 frames, last time 20000.000
	#com of group 18 plus com of group 19:
	#  Number of samples:  2001
	#  Average distance:   4.16814  nm
	#  Standard deviation: 0.11397  nm
	
	$calc_d  -e dist.xvg  -o ddist.xvg
	$calc_d  -e bsa.xvg  -o dbsa.xvg
	#$calc_d  -e fnat_start.txt  -o dfnat_start.xvg

	gmx xpm2ps -f covara.xpm -o covara.eps -do covara.m2p	

	#https://manual.gromacs.org/2023.2/onlinehelp/gmx-dssp.html
	gmx dssp -f md_0_1_noPBC.xtc -s md_0_1.tpr -o ss.dat -tu ns -dt 0.05 -num dssp.xvg

	#echo 1 |gmx do_dssp -f md_0_1_noPBC.xtc -s md_0_1.tpr -n indee0 -o ss.xpm -sc sscore.xvg -a area.xpm -ver 4 # 二级结构
	gmx xpm2ps -f ss.xpm -o ss.eps --by 10 -bx 4 -rainbow no


    # PPI 氨基酸作用分析
    echo -e "17\n0" | gmx trjconv -s md_0_1.tpr -f md_0_1_noPBC.xtc -n index.ndx -o com_traj.xtc -pbc mol -center -b 200000 -e 205000
    conda activate gmxa
    gmx_MMPBSA -O -i mmpbsa.in -cs md_0_1.tpr -ct com_traj.xtc -ci index.ndx -cg 18 19 -cp topol.top -o FINAL_RESULTS_MMPBSA.dat -eo FINAL_RESULTS_MMPBSA.csv -do FINAL_DECOMP_MMPBSA.dat -deo FINAL_DECOMP_MMPBSA.csv
    conda deactivate



    #gmx xpm2ps -f ss.xpm -di xpm2ps.m2p -by 10 -bx 4 -o ss.eps -rainbow no # 二级结构 转换xpm矩阵, 运行有误
    #-di 指定一个.m2p文件，对输出图片的格式进行参数设置。
    #-bx 元素的x大小，当X轴过长可设为2
    #-by 元素的y大小    


	# #轨迹20-30ns 开始20000ps,结束30000ps采样,optional::nojump -dt 100,-dt 保留的时间精度.
	# echo 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 | gmx trjconv -s md_0_1.tpr -f md_0_1_noPBC.xtc -o md_20_30_noPBC.xtc -b 20000 -e 30000
	# echo 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 |gmx trjconv -s md_0_1.tpr -f md_20_30_noPBC.xtc -o md_20_30_noPBC.gro   -dump 0
	# echo -e "q\n" |gmx make_nde0 -f md_20_30_noPBC.gro -o index1.ndx
	# echo -e "4\n4" | gmx rms -s md_0_1.tpr -f md_20_30_noPBC.xtc -o complex_RMSD_Backbone23.xvg -tu ns
	# echo -e "4\n4" | gmx rms -s em.tpr -f md_20_30_noPBC.xtc -o complex_RMSD_Xtal_Backbone23.xvg -tu ns
	# echo 3 |gmx rmsf -f md_20_30_noPBC.xtc -s md_0_1.tpr -o complex_RMSF23.xvg
	# echo 3 |gmx rmsf -f md_20_30_noPBC.xtc -s md_0_1.tpr -o complex_RMSF_res23.xvg -res
	# echo 1 |gmx gyrate -s md_0_1.tpr -f md_20_30_noPBC.xtc -o complex_Radius_of_gyration23.xvg
	# echo 3 |gmx gyrate -s md_0_1.tpr -f md_20_30_noPBC.xtc -o complex_Radius_of_gyration_backbone23.xvg
else
    echo "Exiting..."
    exit 0
fi
