import sys
import zipfile
import xml.etree.ElementTree as ET
import json
import csv

def parse_csv(file_path):
    result = []
    # Try utf-8-sig first to strip BOM if present, fallback to utf-8, utf-16, latin-1
    for enc in ['utf-8-sig', 'utf-8', 'utf-16', 'latin-1']:
        try:
            with open(file_path, mode='r', encoding=enc) as f:
                sample = f.read(4096)
                f.seek(0)
                delimiter = ','
                try:
                    dialect = csv.Sniffer().sniff(sample, delimiters=',;\t')
                    delimiter = dialect.delimiter
                except Exception:
                    if sample.count(';') > sample.count(','):
                        delimiter = ';'
                    elif sample.count('\t') > sample.count(','):
                        delimiter = '\t'

                reader = csv.reader(f, delimiter=delimiter)
                for row in reader:
                    if len(row) >= 2:
                        a, b = str(row[0]).strip(), str(row[1]).strip()
                        if a and b:
                            result.append([a, b])
            if result:
                return result
        except Exception:
            continue
    return result

def parse_xlsx(file_path):
    try:
        with zipfile.ZipFile(file_path, 'r') as z:
            # 1. Read shared strings
            shared_strings = []
            ss_path = next((n for n in z.namelist() if n.lower() == 'xl/sharedstrings.xml'), None)
            if ss_path:
                try:
                    with z.open(ss_path) as f:
                        tree = ET.parse(f)
                        root = tree.getroot()
                        ns = {'ns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
                        for si in root.findall('.//ns:si', ns):
                            text_parts = [t.text for t in si.findall('.//ns:t', ns) if t.text]
                            shared_strings.append(''.join(text_parts))
                except Exception as e:
                    sys.stderr.write(f"Error reading sharedStrings: {e}\n")

            # 2. Locate worksheet
            sheet_files = [n for n in z.namelist() if n.startswith('xl/worksheets/') and n.endswith('.xml')]
            if not sheet_files:
                return []
            sheet_path = 'xl/worksheets/sheet1.xml' if 'xl/worksheets/sheet1.xml' in sheet_files else sorted(sheet_files)[0]

            with z.open(sheet_path) as f:
                tree = ET.parse(f)
                root = tree.getroot()
                ns = {'ns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}

                rows = {}
                row_elements = root.findall('.//ns:row', ns)
                for auto_idx, row in enumerate(row_elements, start=1):
                    r_idx = int(row.get('r', auto_idx))
                    row_data = {}
                    c_elements = row.findall('ns:c', ns)
                    for col_idx, c in enumerate(c_elements):
                        r = c.get('r', '')
                        col = ''.join([char for char in r if char.isalpha()]).upper()
                        if not col:
                            col = chr(ord('A') + col_idx) if col_idx < 26 else f"COL{col_idx}"

                        t = c.get('t', '')
                        val = ''
                        if t == 's':
                            v_elem = c.find('ns:v', ns)
                            if v_elem is not None and v_elem.text is not None:
                                try:
                                    s_idx = int(v_elem.text)
                                    if 0 <= s_idx < len(shared_strings):
                                        val = shared_strings[s_idx]
                                except ValueError:
                                    val = ''
                        elif t == 'inlineStr':
                            is_elem = c.find('ns:is', ns)
                            if is_elem is not None:
                                text_parts = [elem.text for elem in is_elem.findall('.//ns:t', ns) if elem.text]
                                val = ''.join(text_parts)
                            else:
                                t_elem = c.find('.//ns:t', ns)
                                if t_elem is not None and t_elem.text:
                                    val = t_elem.text
                        else:
                            # Direct value or number
                            v_elem = c.find('ns:v', ns)
                            if v_elem is not None and v_elem.text is not None:
                                val = v_elem.text
                            else:
                                t_elem = c.find('.//ns:t', ns)
                                if t_elem is not None and t_elem.text:
                                    val = t_elem.text

                        row_data[col] = val

                    if 'A' in row_data and 'B' in row_data:
                        a = str(row_data['A']).strip()
                        b = str(row_data['B']).strip()
                        if a and b:
                            rows[r_idx] = (a, b)

                result = []
                for r_idx in sorted(rows.keys()):
                    result.append([rows[r_idx][0], rows[r_idx][1]])
                return result
    except Exception as e:
        sys.stderr.write(f"Error parsing xlsx: {e}\n")
        return None

def parse_file(file_path):
    if file_path.lower().endswith('.csv'):
        return parse_csv(file_path)
    else:
        res = parse_xlsx(file_path)
        if res is None:
            res = parse_csv(file_path)
        return res

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 xlsx_parser.py <file>")
        sys.exit(1)
    res = parse_file(sys.argv[1])
    if res is not None:
        print(json.dumps(res, ensure_ascii=False))
    else:
        sys.exit(1)
