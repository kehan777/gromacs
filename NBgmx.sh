#!/bin/bash

folder_path="$(pwd)"

# 遍历当前文件夹下的所有pdb文件
for file in "$folder_path"/*.pdb; do
    # 提取pdb文件名（不包含扩展名）
    filename=$(basename "$file" .pdb)

    # 创建对应的文件夹
    mkdir "$folder_path/$filename"

    # 移动pdb文件到对应的文件夹
    cp "$file" "$folder_path/$filename/"
    # 移动gmxcript.sh文件到对应的文件夹
    cp gmxcript_complex.sh "$folder_path/$filename/"
    cp gmxcript_analysis.sh "$folder_path/$filename/"
    cp renumber_bychain.py "$folder_path/$filename/"
    # 复制mdp文件到每个文件夹下
    for file in "$folder_path"/*.mdp; do
        #if [[ ! -d "$file" && ! "$file" =~ \.pdb$ ]]; then
            # 复制非pdb文件到每个文件夹下
        cp "$file" "$folder_path/$filename/"
        done
        #fi   
    for file in "$folder_path"/mmpbsa.in; do
        #if [[ ! -d "$file" && ! "$file" =~ \.pdb$ ]]; then
            # 复制非pdb文件到每个文件夹下
        cp "$file" "$folder_path/$filename/"
        done
        #fi 


done

# 遍历每个文件夹
for file in "$folder_path"/*.pdb; do
# 进入文件夹
    folder=$(basename "$file" .pdb)
    cd "$folder" || continue
    pwd
    echo $(basename "$folder")
    # 查找并替换gmxcript_complex.sh文件中的内容
    sed -i "s/complex/$(basename "$folder")/g" gmxcript_complex.sh
    # 授予.sh文件执行权限
    chmod +x -R $folder_path
    # 运行gmxcript_complex.sh文件
    ./gmxcript_complex.sh

    # 退出文件夹
    cd "$folder_path" || exit
done

for folder in "$folder_path"/*.pdb; do
    folder=$(basename "$file" .pdb)
# 进入文件夹
    cd "$folder" || continue
    pwd
    echo $(basename "$folder")
    # 查找并替换gmxcript_analysis.sh文件中的内容
    sed -i "s/complex/$(basename "$folder")/g" gmxcript_analysis.sh
    # 授予.sh文件执行权限
    chmod +x gmxcript_analysis.sh
    # 运行gmxcript_complex.sh文件
    #./gmxcript_analysis.sh

    # 退出文件夹
    cd "$folder_path" || exit
done


#cd "/home/adsb/protest"
