python .\format_injuries.py "model speculative_aware_fraction-spreadsheet.csv"
python fuse_runs.py
python write_hist.py tex_hist.tex combined.txt output.tex