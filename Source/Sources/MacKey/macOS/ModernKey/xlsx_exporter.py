import sys
import zipfile
import json
import csv
import os
import unicodedata
import xml.sax.saxutils as saxutils

def clean_xml_string(val):
    if val is None:
        return ""
    # Normalize to NFC (Unicode Dựng Sẵn - standard precomposed form)
    s = unicodedata.normalize('NFC', str(val))
    # Remove XML 1.0 illegal control characters
    return "".join(
        ch for ch in s
        if ch in ('\t', '\n', '\r')
        or 32 <= ord(ch) <= 0xd7ff
        or 0xe000 <= ord(ch) <= 0xfffd
        or 0x10000 <= ord(ch) <= 0x10ffff
    )

def export_file(data_json_str, file_path):
    try:
        data = json.loads(data_json_str)
        if file_path.lower().endswith('.csv'):
            with open(file_path, mode='w', encoding='utf-8-sig', newline='') as f:
                writer = csv.writer(f)
                for item in data:
                    writer.writerow([unicodedata.normalize('NFC', str(cell)) for cell in item])
            return True
        else:
            # Excel OpenXML (.xlsx) strictly compliant with ECMA-376
            unique_strings = []
            str_to_idx = {}

            def get_str_idx(s):
                clean_s = clean_xml_string(s)
                if clean_s not in str_to_idx:
                    str_to_idx[clean_s] = len(unique_strings)
                    unique_strings.append(clean_s)
                return str_to_idx[clean_s]

            sheet_rows = []
            for r_idx, row in enumerate(data, start=1):
                cells = []
                for c_idx, val in enumerate(row):
                    col_letter = chr(ord('A') + c_idx)
                    s_idx = get_str_idx(val)
                    cell_ref = f"{col_letter}{r_idx}"
                    cells.append(f'<c r="{cell_ref}" t="s"><v>{s_idx}</v></c>')
                sheet_rows.append(f'<row r="{r_idx}">{"".join(cells)}</row>')

            num_rows = len(data)
            dimension_ref = f"A1:B{max(1, num_rows)}"

            # 1. [Content_Types].xml
            content_types = (
                '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
                '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n'
                '  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n'
                '  <Default Extension="xml" ContentType="application/xml"/>\n'
                '  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\n'
                '  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\n'
                '  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>\n'
                '  <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>\n'
                '</Types>'
            )

            # 2. _rels/.rels
            rels = (
                '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
                '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
                '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\n'
                '</Relationships>'
            )

            # 3. xl/workbook.xml
            workbook = (
                '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
                '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\n'
                '  <sheets>\n'
                '    <sheet name="Sheet1" sheetId="1" r:id="rId1"/>\n'
                '  </sheets>\n'
                '</workbook>'
            )

            # 4. xl/_rels/workbook.xml.rels
            workbook_rels = (
                '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
                '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
                '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>\n'
                '  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>\n'
                '  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>\n'
                '</Relationships>'
            )

            # 5. xl/styles.xml with standard font family
            styles = (
                '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
                '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\n'
                '  <fonts count="1">\n'
                '    <font>\n'
                '      <sz val="11"/>\n'
                '      <color theme="1"/>\n'
                '      <name val="Calibri"/>\n'
                '      <family val="2"/>\n'
                '      <scheme val="minor"/>\n'
                '    </font>\n'
                '  </fonts>\n'
                '  <fills count="2">\n'
                '    <fill><patternFill patternType="none"/></fill>\n'
                '    <fill><patternFill patternType="gray125"/></fill>\n'
                '  </fills>\n'
                '  <borders count="1">\n'
                '    <border><left/><right/><top/><bottom/><diagonal/></border>\n'
                '  </borders>\n'
                '  <cellStyleXfs count="1">\n'
                '    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>\n'
                '  </cellStyleXfs>\n'
                '  <cellXfs count="1">\n'
                '    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>\n'
                '  </cellXfs>\n'
                '</styleSheet>'
            )

            # 6. xl/sharedStrings.xml
            sst_items = []
            for s in unique_strings:
                esc_s = saxutils.escape(s)
                space_attr = ' xml:space="preserve"' if (esc_s.startswith(' ') or esc_s.endswith(' ') or '\n' in esc_s) else ''
                sst_items.append(f'<si><t{space_attr}>{esc_s}</t></si>')

            shared_strings = (
                '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
                f'<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="{len(unique_strings)}" uniqueCount="{len(unique_strings)}">\n'
                + "".join(sst_items) +
                '\n</sst>'
            )

            # 7. xl/worksheets/sheet1.xml with readable column widths
            sheet_content = (
                '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
                '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\n'
                f'  <dimension ref="{dimension_ref}"/>\n'
                '  <sheetViews>\n'
                '    <sheetView tabSelected="1" workbookViewId="0"/>\n'
                '  </sheetViews>\n'
                '  <sheetFormatPr defaultRowHeight="15"/>\n'
                '  <cols>\n'
                '    <col min="1" max="1" width="18" customWidth="1"/>\n'
                '    <col min="2" max="2" width="40" customWidth="1"/>\n'
                '  </cols>\n'
                '  <sheetData>\n'
                + '\n'.join(sheet_rows) + '\n'
                '  </sheetData>\n'
                '</worksheet>'
            )

            with zipfile.ZipFile(file_path, 'w', compression=zipfile.ZIP_DEFLATED) as z:
                z.writestr('[Content_Types].xml', content_types)
                z.writestr('_rels/.rels', rels)
                z.writestr('xl/workbook.xml', workbook)
                z.writestr('xl/_rels/workbook.xml.rels', workbook_rels)
                z.writestr('xl/styles.xml', styles)
                z.writestr('xl/sharedStrings.xml', shared_strings)
                z.writestr('xl/worksheets/sheet1.xml', sheet_content)
            return True
    except Exception as e:
        sys.stderr.write(str(e) + '\n')
        return False

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python3 xlsx_exporter.py <data_json_str_or_file_or_-> <output_file>")
        sys.exit(1)
    
    arg1 = sys.argv[1]
    output_path = sys.argv[2]
    
    if arg1 == '-':
        data_str = sys.stdin.read()
    elif os.path.isfile(arg1):
        with open(arg1, 'r', encoding='utf-8') as f:
            data_str = f.read()
    else:
        data_str = arg1

    success = export_file(data_str, output_path)
    if success:
        sys.exit(0)
    else:
        sys.exit(1)
