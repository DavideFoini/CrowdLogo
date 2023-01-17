python .\format_injuries.py "model speculative_panic_fraction-spreadsheet.csv"
python fuse_runs.py
python write_hist.py tex_hist.tex combined.txt output.tex