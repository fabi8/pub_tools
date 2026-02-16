import os
import re
import argparse
import openpyxl

start_dir = ""

def print_excel_match(file_path:str, sheet_name:str, matching_row:list, headers:list, only_path:bool):
    """Print the matched row with headers."""
    if matching_row == headers:
        # If this is header, then do not print it zipped with itsself
        row_dict = matching_row
    else:
        row_dict = dict(zip(headers, matching_row))

    w_rel_path = os.path.relpath(file_path, start_dir)
    u_rel_path = w_rel_path.replace('\\', '/')
    if (only_path):
        print(f"{u_rel_path}")
    else:
        print(f"{u_rel_path}: {sheet_name}: {row_dict}")

def search_excel(file_path:str, cregex, column_name:str=None, list_only:bool=False):
    """Search for a value in a specific column by the compiled regular expression.
      Print the whole row with column headers if matched."""
    try:
        wb = openpyxl.load_workbook(file_path, read_only=True, data_only=True)
        for sheet in wb.worksheets:
            rows = list(sheet.iter_rows(values_only=True))
            if not rows:
                continue
            headers = [str(h) if h is not None else "" for h in rows[0]]
            if column_name is not None:
                if column_name not in headers:
                    continue
                col_idx = headers.index(column_name)
                for row in rows[1:]:
                    res = cregex.match(str(row[col_idx]))
                    if res:
                        print_excel_match(file_path, sheet.title, list(row), headers, only_path=list_only)
                        if list_only:
                            return
            else:
                for row in rows:
                    for cell in row:
                        if cell is not None:
                            res = cregex.match(str(cell))
                            if res:
                                print_excel_match(file_path, sheet.title, list(row), headers, only_path=list_only)
                                if list_only:
                                    return
        wb.close()
    except Exception as e:
        pass  # Optionally handle/log errors

def list_xlsx_files(start_directory:str,recursive:bool=False):
    """Recursively list all .xlsx files starting from the specified directory."""
    def is_excel_file(filename):
        return (filename.endswith('.xlsx') or filename.endswith('.xls')) and not filename.startswith('~')
    
    files = []
    if recursive:
        for dirpath, dirnames, filenames in os.walk(start_directory):
            for filename in filenames:
                if is_excel_file(filename):
                    files.append( os.path.join(dirpath, filename))
    else:
        for filename in os.listdir(start_directory):
            if is_excel_file(filename):
                files.append(os.path.join(start_directory, filename))
    return files

def main():
    parser = argparse.ArgumentParser(description="Search for a regex pattern in Excel files (xlsx and xls)")
    parser.add_argument("regex_pattern", help="Regex pattern to search for")
    parser.add_argument("-r", action="store_true", help="Recursively search in subdirectories")
    parser.add_argument("-i", action="store_true", help="Ignore case in regex matching")
    parser.add_argument("-l", action="store_true", help="Print only first match in each file")
    parser.add_argument("-c", "--column", type=str, help="Column name to search. If not specified, search all columns")
    args = parser.parse_args()

    flags = re.DOTALL
    if args.i:
        flags |= re.IGNORECASE
    cregex = re.compile(args.regex_pattern, flags=flags)

    global start_dir
    start_dir = os.getcwd()
    # print(f"Searching in directory: {start_directory}")
    files = list_xlsx_files(start_dir, args.r)
    for file in files:
        # print(f"Processing file: {file}")
        search_excel(file_path=file, column_name=args.column, cregex=cregex, list_only=args.l)

    print("Total processed: ", len(files))

if __name__ == "__main__":
    main()
