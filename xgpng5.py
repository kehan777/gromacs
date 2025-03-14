import os
import matplotlib.pyplot as plt
import numpy as np
import re
import matplotlib.font_manager as fm
from matplotlib.colors import LinearSegmentedColormap

def sanitize_filename(filename):
    return re.sub(r'[<>:"/\\|?*]', '_', filename)

def process_xvg_files(root_dir):
    for root, dirs, files in os.walk(root_dir):
        for file in files:
            if file.endswith('.xvg'):
                print(file)
                xvg_path = os.path.join(root, file)
                file_name = os.path.splitext(file)[0]
                plot_xvg_file(xvg_path, file_name)

def plot_xvg_file(xvg_path, file_name):
    try:
        with open(xvg_path, 'r', encoding='utf-8') as file:
            lines = file.readlines()
    except UnicodeDecodeError:
        with open(xvg_path, 'r', encoding='iso-8859-1') as file:
            lines = file.readlines()

    titer = ''
    xaxis_label = ''
    yaxis_label = ''
    x = []
    y = []
    sx_legend = []

    for line in lines:
        if line.startswith('#'):
            continue   
        if line.startswith('@'):
            if line.startswith('@    title'):
                titer = line.strip().split('"')[1]
            elif line.startswith('@    xaxis'):
                xaxis_label = line.strip().split('"')[1]
            elif line.startswith('@    yaxis'):
                yaxis_label = line.strip().split('"')[1]
            continue

        values = line.strip().split()
        x.append(float(values[0]))
        y.append([float(val) for val in values[1:]])

    x = np.array(x)
    y = np.array(y)

    title_font = fm.FontProperties(family='Arial', weight='bold', size=14)
    label_font = fm.FontProperties(family='Arial', weight='bold', size=14)
    tick_font = fm.FontProperties(family='Arial', size=12)

    fig, ax = plt.subplots(figsize=(12, 8))
    
    if y.ndim == 1:
        ax.plot(x, y, color='black', linewidth=0.9, antialiased=True)
    else:
        for i in range(y.shape[1]):
            ax.plot(x, y[:, i], color='black', linewidth=0.9, antialiased=True)

    title = file_name
    ax.set_title(title, fontproperties=title_font)
    ax.set_xlabel(xaxis_label, fontproperties=label_font)
    ax.set_ylabel(yaxis_label, fontproperties=label_font)

    ax.tick_params(axis='both', which='major', labelsize=10)
    for label in ax.get_xticklabels() + ax.get_yticklabels():
        label.set_fontproperties(tick_font)

    ax.set_xlim(left=0)

    output_dir = os.path.dirname(xvg_path)
    output_filename = sanitize_filename(os.path.splitext(os.path.basename(xvg_path))[0] + '.png')
    output_path = os.path.join(output_dir, output_filename)
    os.makedirs(output_dir, exist_ok=True)

    try:
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
    except Exception as e:
        print(f"Error saving figure to {output_path}: {e}")
    plt.close(fig)

#root_folder = r'E:\grx_out\AFDS003\PM1'
root_folder = r'D:\grx\TfR8_23'
process_xvg_files(root_folder)