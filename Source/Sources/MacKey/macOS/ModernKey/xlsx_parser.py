import sys
import zipfile
import xml.etree.ElementTree as ET
import json
import csv

def parse_file(file_path):
    try:
        if file_path.lower().endswith('.csv'):
            result = []
            with open(file_path, mode='r', encoding='utf-8', errors='ignore') as f:
                reader = csv.reader(f)
                for row in reader:
                    if len(row) >= 2:
                        a, b = row[0], row[1]
                        if a.strip() and b.strip():
                            result.append([a.strip(), b.strip()])
            return result
        else:
            # Excel (.xlsx)
            with zipfile.ZipFile(file_path, 'r') as z:
                # 1. Read shared strings
                shared_strings = []
                try:
                    with z.open('xl/sharedStrings.xml') as f:
                        tree = ET.parse(f)
                        root = tree.getroot()
                        ns = {'ns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
                        for si in root.findall('.//ns:t', ns):
                            shared_strings.append(si.text or '')
                except KeyError:
                    pass
                
                # 2. Read sheet1
                with z.open('xl/worksheets/sheet1.xml') as f:
                    tree = ET.parse(f)
                    root = tree.getroot()
                    ns = {'ns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
                    
                    rows = {}
                    for row in root.findall('.//ns:row', ns):
                        r_idx = row.get('r')
                        row_data = {}
                        for c in row.findall('ns:c', ns):
                            r = c.get('r')
                            col = ''.join([char for char in r if char.isalpha()])
                            t = c.get('t')
                            v_elem = c.find('ns:v', ns)
                            val = ''
                            if v_elem is not None:
                                v_text = v_elem.text
                                if t == 's':
                                    idx = int(v_text)
                                    val = shared_strings[idx] if idx < len(shared_strings) else ''
                                else:
                                    val = v_text or ''
                            row_data[col] = val
                        if 'A' in row_data and 'B' in row_data:
                            rows[r_idx] = (row_data['A'], row_data['B'])
                    
                    result = []
                    for r_idx in sorted(rows.keys(), key=int):
                        a, b = rows[r_idx]
                        if a.strip() and b.strip():
                            result.append([a.strip(), b.strip()])
                    return result
    except Exception as e:
        sys.stderr.write(str(e) + '\n')
        return None

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 xlsx_parser.py <file>")
        sys.exit(1)
    res = parse_file(sys.argv[1])
    if res is not None:
        print(json.dumps(res, ensure_ascii=False))
    else:
        sys.exit(1)
