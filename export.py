#!/usr/bin/env python

import subprocess
import os
import sys
import shutil

script_dir = os.path.abspath(os.path.dirname(__file__))

def main():
    jname = sys.argv[1]
    if len(sys.argv) > 2 and sys.argv[2] == '--save-pdf':
        save_pdf = True
    
    export(jname, save_pdf)

def run(cwd, *args):
    proc = subprocess.Popen(args, cwd=cwd)
    result = proc.wait()
    if result != 0:
        raise Exception('Execution failed: {0}'.format(args))

def export(jname, save_pdf):
    export_dir = os.path.join(script_dir, 'export_{}'.format(jname))
    
    if os.path.exists(export_dir):
        sys.stderr.write('{} already exists; aborting\n'.format(export_dir))
        sys.exit(1)
    
    os.mkdir(export_dir)
    
    def redirect(outfile, filename, substitute_input = False):
        with open(os.path.join(script_dir, filename)) as infile:
            for line in infile:
                line_stripped = line.strip()
                if line_stripped.startswith('%'):
                    pass
                elif substitute_input and line_stripped.startswith('\\input'):
                    redirect(outfile, line_stripped[7:-1])
                elif line_stripped.startswith('\\includegraphics'):
                    filename_pieces = line_stripped.split('{')
                    prefix = filename_pieces[0]
                    filename = filename_pieces[1][:-1]
                    new_filename = 'figure{}{}.pdf'.format(
                        'S' if redirect.in_supplement else '',
                        redirect.figure_num
                    )
                    shutil.copy(
                        os.path.join(script_dir, filename),
                        os.path.join(export_dir, new_filename)
                    )
                    redirect.figure_num += 1
                    
                    outfile.write('{}{{{}}}\n'.format(prefix, new_filename))
                else:
                    if line_stripped == '\\beginsupplement':
                        redirect.in_supplement = True
                        redirect.figure_num = 1
                    
                    outfile.write(line_stripped)
                    outfile.write('\n')
    redirect.in_supplement = False
    redirect.figure_num = 1
    
    filename = 'ccm_ms_{}.tex'.format(jname)
    with open(os.path.join(export_dir, 'ccm_ms.tex'), 'w') as outfile:
        redirect(outfile, filename, substitute_input = True)
    
    shutil.copy(os.path.join(script_dir, 'ccm_ms.bib'), export_dir)
    shutil.copy(os.path.join(script_dir, 'plos2015.bst'), export_dir)
    
    run(export_dir, 'pdflatex', 'ccm_ms')
    run(export_dir, 'bibtex', 'ccm_ms')
    run(export_dir, 'pdflatex', 'ccm_ms')
    run(export_dir, 'pdflatex', 'ccm_ms')
    
    os.remove(os.path.join(export_dir, 'ccm_ms.aux'))
    os.remove(os.path.join(export_dir, 'ccm_ms.bib'))
    os.remove(os.path.join(export_dir, 'ccm_ms.blg'))
    os.remove(os.path.join(export_dir, 'ccm_ms.log'))
    os.remove(os.path.join(export_dir, 'ccm_ms.out'))
    os.remove(os.path.join(export_dir, 'plos2015.bst'))
    
    if not save_pdf:
        os.remove(os.path.join(export_dir, 'ccm_ms.pdf'))

if __name__ == '__main__':
    main()
