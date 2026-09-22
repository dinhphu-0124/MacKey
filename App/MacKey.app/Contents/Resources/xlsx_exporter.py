import sys
import zipfile
import json
import csv
import html

def export_file(data_json_str, file_path):
    try:
        data = json.loads(data_json_str)
        if file_path.lower().endswith('.csv'):
            with open(file_path, mode='w', encoding='utf-8-sig', newline='') as f:
                writer = csv.writer(f)
                for item in data:
                    writer.writerow(item)
            return True
        else:
            # Excel (.xlsx)
            with zipfile.ZipFile(file_path, 'w') as z:
                # 1. Write [Content_Types].xml
                content_types = (
                    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
                    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n'
                    '  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n'
                    '  <Default Extension="xml" ContentType="application/xml"/>\n'
                    '  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.workbook+xml"/>\n'
                    '  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\n'
                    '</Types>'
                )
                z.writestr('[Content_Types].xml', content_types)

                # 2. Write _rels/.rels
                rels = (
                    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
                    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
                    '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\n'
                    '</Relationships>'
                )
                z.writestr('_rels/.rels', rels)

                # 3. Write xl/workbook.xml
                workbook = (
                    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
                    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\n'
                    '  <sheets>\n'
                    '    <sheet name="Sheet1" sheetId="1" r:id="rId1"/>\n'
                    '  </sheets>\n'
                    '</workbook>'
                )
                z.writestr('xl/workbook.xml', workbook)

                # 4. Write xl/_rels/workbook.xml.rels
                workbook_rels = (
                    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
                    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
                    '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>\n'
                    '</Relationships>'
                )
                z.writestr('xl/_rels/workbook.xml.rels', workbook_rels)

                # 5. Write xl/worksheets/sheet1.xml
                sheet_rows = []
                for idx, item in enumerate(data, start=1):
                    shortcut, replacement = item[0], item[1]
                    esc_shortcut = html.escape(str(shortcut))
                    esc_replacement = html.escape(str(replacement))
                    row_str = (
                        f'<row r="{idx}">\n'
                        f'  <c r="A{idx}" t="inlineStr"><is><t>{esc_shortcut}</t></is></c>\n'
                        f'  <c r="B{idx}" t="inlineStr"><is><t>{esc_replacement}</t></is></c>\n'
                        f'</row>'
                    )
                    sheet_rows.append(row_str)

                sheet_content = (
                    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
                    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\n'
                    '  <sheetData>\n'
                    + '\n'.join(sheet_rows) + '\n'
                    + '  </sheetData>\n'
                    '</worksheet>'
                )
                z.writestr('xl/worksheets/sheet1.xml', sheet_content)
            return True
    except Exception as e:
        sys.stderr.write(str(e) + '\n')
        return False

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python3 xlsx_exporter.py <data_json_str> <output_file>")
        sys.exit(1)
    success = export_file(sys.argv[1], sys.argv[2])
    if success:
        sys.exit(0)
    else:
        sys.exit(1)
