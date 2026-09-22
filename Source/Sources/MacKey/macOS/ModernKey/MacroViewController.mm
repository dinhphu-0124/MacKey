
#import "MacroViewController.h"
#import "MacKeyManager.h"
#include "Engine.h"

#define MACRO_ADD_TEXT @"Thêm"
#define MACRO_EDIT_TEXT @"Sửa"

@interface MacroViewController ()

@end

@implementation MacroViewController{
    vector<vector<Uint32>> keys;
    vector<string> macroText;
    vector<string> macroContent;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    
    self.macroName.delegate = self;
    self.macroContent.delegate = self;
    
    self.AutoCapsMacro.state = vAutoCapsMacro ? NSControlStateValueOn : NSControlStateValueOff;
    
    // Force column widths programmatically to align with input fields
    self.tableView.tableColumns[0].width = 137;
    self.tableView.tableColumns[1].width = 396;
    
    //load data
    getAllMacro(keys, macroText, macroContent);
    [self updateButtonStates];
}

-(void)saveAndReload {
    getAllMacro(keys, macroText, macroContent);
    [self.tableView reloadData];
    
    vector<Byte> macroData;
    getMacroSaveData(macroData);
    NSData* _data = [NSData dataWithBytes:macroData.data() length:macroData.size()];
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:_data forKey:@"macroData"];
    [self updateButtonStates];
}

- (IBAction)onDeleteMacro:(id)sender {
    if ([[self.macroName stringValue] compare:@""] == 0) {
        [self showMessage:@"Bạn hãy chọn từ cần xoá!"];
        return;
    }
    string text = [[self.macroName stringValue] UTF8String];
    if (deleteMacro(text)) {
        self.macroName.stringValue = @"";
        self.macroContent.stringValue = @"";
        [self saveAndReload];
        [self.macroName becomeFirstResponder];
    }
}

- (IBAction)onAddMacro:(id)sender {
    if ([[self.macroName stringValue] compare:@""] == 0 || [[self.macroContent stringValue] compare:@""] == 0) {
        [self showMessage:@"Bạn hãy nhập từ cần gõ tắt!"];
        return;
    }
    
    string text = [[self.macroName stringValue] UTF8String];
    string content = [[self.macroContent stringValue] UTF8String];

    addMacro(text, content);
    self.macroName.stringValue = @"";
    self.macroContent.stringValue = @"";
    [self saveAndReload];
    [self.macroName becomeFirstResponder];
}

- (IBAction)onImportFromExcel:(id)sender {
    NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseFiles:YES];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setAllowedFileTypes:@[@"xlsx", @"csv"]];
    
    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
        if (result != NSModalResponseOK) {
            return;
        }
        
        NSURL* fileURL = [[openPanel URLs] firstObject];
        if (!fileURL) {
            return;
        }
        
        [self importFromExcelOrCSV:fileURL.path];
    }];
}

- (void)importFromExcelOrCSV:(NSString*)filePath {
    NSString* scriptPath = [[NSBundle mainBundle] pathForResource:@"xlsx_parser" ofType:@"py"];
    if (!scriptPath) {
        NSString* resPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"xlsx_parser.py"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:resPath]) {
            scriptPath = resPath;
        }
    }
    if (!scriptPath) {
        [self showMessage:@"Không tìm thấy bộ phân tích tệp Excel trong ứng dụng."];
        return;
    }
    
    NSString* pythonPath = @"/usr/bin/python3";
    if (![[NSFileManager defaultManager] fileExistsAtPath:pythonPath]) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:@"/opt/homebrew/bin/python3"]) {
            pythonPath = @"/opt/homebrew/bin/python3";
        } else if ([[NSFileManager defaultManager] fileExistsAtPath:@"/usr/local/bin/python3"]) {
            pythonPath = @"/usr/local/bin/python3";
        }
    }
    
    NSTask* task = [[NSTask alloc] init];
    [task setLaunchPath:pythonPath];
    [task setArguments:@[scriptPath, filePath]];
    
    NSMutableDictionary* env = [[[NSProcessInfo processInfo] environment] mutableCopy];
    env[@"LC_ALL"] = @"en_US.UTF-8";
    env[@"PYTHONIOENCODING"] = @"utf-8";
    [task setEnvironment:env];
    
    NSPipe* outputPipe = [NSPipe pipe];
    NSPipe* errorPipe = [NSPipe pipe];
    [task setStandardOutput:outputPipe];
    [task setStandardError:errorPipe];
    
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *exception) {
        [self showMessage:[NSString stringWithFormat:@"Không thể chạy bộ phân tích Python. Lỗi: %@", exception.reason]];
        return;
    }
    
    int status = [task terminationStatus];
    if (status != 0) {
        NSData* errorData = [[errorPipe fileHandleForReading] readDataToEndOfFile];
        NSString* errorMsg = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
        [self showMessage:[NSString stringWithFormat:@"Lỗi khi đọc file Excel/CSV: %@", errorMsg]];
        return;
    }
    
    NSData* outputData = [[outputPipe fileHandleForReading] readDataToEndOfFile];
    NSError* jsonError = nil;
    NSArray* parsedMacros = [NSJSONSerialization JSONObjectWithData:outputData options:kNilOptions error:&jsonError];
    
    if (jsonError || ![parsedMacros isKindOfClass:[NSArray class]]) {
        [self showMessage:@"Dữ liệu Excel/CSV không đúng định dạng."];
        return;
    }
    
    int importedCount = 0;
    for (id item in parsedMacros) {
        if ([item isKindOfClass:[NSArray class]] && [item count] >= 2) {
            NSString* key = item[0];
            NSString* val = item[1];
            std::string text = [key UTF8String];
            std::string content = [val UTF8String];
            if (!text.empty() && !content.empty()) {
                if (addMacro(text, content)) {
                    importedCount++;
                }
            }
        }
    }
    
    [self saveAndReload];
    [self showMessage:[NSString stringWithFormat:@"Đã nhập thành công %d mục gõ tắt.", importedCount]];
}

- (void)showMessage:(NSString*)msg {
    NSAlert* alert = [[NSAlert alloc] init];
    [alert setInformativeText:msg];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:@"Gõ tắt"];
    [alert setAlertStyle:NSAlertStyleCritical];
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {

    }];
}

- (void)controlTextDidChange:(NSNotification *)notification {
    NSTextField *textField = [notification object];
    if (textField == self.macroName) {
        [self updateButtonStates];
    }
}

- (IBAction)onAutoCapButton:(NSButton *)sender {
    NSInteger val = sender.state == NSControlStateValueOn ? 1 : 0;
    MacKeyStateLock();
    vAutoCapsMacro = (int)val;
    MacKeyStateUnlock();
    [[NSUserDefaults standardUserDefaults] setInteger:vAutoCapsMacro forKey:@"vAutoCapsMacro"];
}

#pragma mark TableView
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return keys.size();
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString* cellId;
    NSTableCellView* v = nil;
    if (tableColumn == tableView.tableColumns[0]) {
        cellId = @"MacroCell";
        v = [tableView makeViewWithIdentifier:cellId owner:self];
        [v.textField setStringValue:[NSString stringWithUTF8String:macroText[row].c_str()]];
    } else if (tableColumn == tableView.tableColumns[1]) {
        cellId = @"ContentCell";
        v = [tableView makeViewWithIdentifier:cellId owner:self];
        [v.textField setStringValue:[NSString stringWithUTF8String:macroContent[row].c_str()]];
    }
    return v;
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    [self.macroName setStringValue:[NSString stringWithUTF8String:macroText[row].c_str()]];
    [self.macroContent setStringValue:[NSString stringWithUTF8String:macroContent[row].c_str()]];
    [self updateButtonStates];
    return YES;
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (commandSelector == @selector(insertNewline:)) {
        if (control == self.macroName) {
            [self.macroContent becomeFirstResponder];
            return YES;
        } else if (control == self.macroContent) {
            [self onAddMacro:control];
            return YES;
        }
    }
    return NO;
}

- (void)updateButtonStates {
    NSString *nameText = [self.macroName stringValue];
    std::string text = [nameText UTF8String];
    
    BOOL exists = hasMacro(text);
    
    if (exists) {
        // Mode: Editing
        [self.buttonAdd setTitle:@"Cập nhật"];
        [self.buttonAdd setFrame:NSMakeRect(410, 404, 80, 32)];
        self.buttonAdd.hidden = NO;
        
        [self.buttonDelete setTitle:@"Xoá"];
        [self.buttonDelete setFrame:NSMakeRect(500, 404, 80, 32)];
        self.buttonDelete.hidden = NO;
    } else {
        // Mode: Adding
        [self.buttonAdd setTitle:@"Thêm"];
        [self.buttonAdd setFrame:NSMakeRect(500, 404, 80, 32)];
        self.buttonAdd.hidden = NO;
        
        self.buttonDelete.hidden = YES;
    }
}


- (IBAction)onExportFile:(id)sender {
    NSAlert* alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Xuất bảng gõ tắt"];
    [alert setInformativeText:@"Bạn muốn xuất danh sách gõ tắt ra định dạng nào?"];
    [alert addButtonWithTitle:@"Excel (.xlsx)"];
    [alert addButtonWithTitle:@"CSV"];
    [alert addButtonWithTitle:@"Huỷ"];
    [alert setAlertStyle:NSAlertStyleCritical]; // Critical alert style like warning pop-ups
    
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertThirdButtonReturn) {
            return; // Cancelled
        }
        
        BOOL isExcel = (returnCode == NSAlertFirstButtonReturn);
        NSString* ext = isExcel ? @"xlsx" : @"csv";
        
        NSSavePanel* savePanel = [NSSavePanel savePanel];
        [savePanel setAllowedFileTypes:@[ext]];
        [savePanel setNameFieldStringValue:[NSString stringWithFormat:@"GoTat_Export.%@", ext]];
        
        [savePanel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
            if (result != NSModalResponseOK) {
                return;
            }
            
            NSURL* fileURL = [savePanel URL];
            if (!fileURL) {
                return;
            }
            
            [self performExportToPath:fileURL.path isExcel:isExcel];
        }];
    }];
}

- (void)performExportToPath:(NSString*)filePath isExcel:(BOOL)isExcel {
    NSString* scriptPath = [[NSBundle mainBundle] pathForResource:@"xlsx_exporter" ofType:@"py"];
    if (!scriptPath) {
        NSString* resPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"xlsx_exporter.py"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:resPath]) {
            scriptPath = resPath;
        }
    }
    if (!scriptPath) {
        [self showMessage:@"Không tìm thấy bộ xuất tệp Excel/CSV trong ứng dụng."];
        return;
    }
    
    // Build data array
    NSMutableArray* dataArray = [NSMutableArray array];
    for (size_t i = 0; i < macroText.size(); i++) {
        NSString* shortcut = [NSString stringWithUTF8String:macroText[i].c_str()];
        NSString* replacement = [NSString stringWithUTF8String:macroContent[i].c_str()];
        if (shortcut && replacement) {
            [dataArray addObject:@[shortcut, replacement]];
        }
    }
    
    NSError* err = nil;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:dataArray options:0 error:&err];
    if (err) {
        [self showMessage:@"Không thể chuyển dữ liệu sang định dạng JSON."];
        return;
    }
    NSString* jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    NSString* pythonPath = @"/usr/bin/python3";
    if (![[NSFileManager defaultManager] fileExistsAtPath:pythonPath]) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:@"/opt/homebrew/bin/python3"]) {
            pythonPath = @"/opt/homebrew/bin/python3";
        } else if ([[NSFileManager defaultManager] fileExistsAtPath:@"/usr/local/bin/python3"]) {
            pythonPath = @"/usr/local/bin/python3";
        }
    }
    
    NSTask* task = [[NSTask alloc] init];
    [task setLaunchPath:pythonPath];
    [task setArguments:@[scriptPath, jsonStr, filePath]];
    
    NSMutableDictionary* env = [[[NSProcessInfo processInfo] environment] mutableCopy];
    env[@"LC_ALL"] = @"en_US.UTF-8";
    env[@"PYTHONIOENCODING"] = @"utf-8";
    [task setEnvironment:env];
    
    NSPipe* errorPipe = [NSPipe pipe];
    [task setStandardError:errorPipe];
    
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *exception) {
        [self showMessage:[NSString stringWithFormat:@"Không thể chạy bộ xuất dữ liệu Python. Lỗi: %@", exception.reason]];
        return;
    }
    
    int status = [task terminationStatus];
    if (status != 0) {
        NSData* errorData = [[errorPipe fileHandleForReading] readDataToEndOfFile];
        NSString* errorMsg = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
        [self showMessage:[NSString stringWithFormat:@"Lỗi khi xuất tệp: %@", errorMsg]];
    } else {
        // Show success warning alert
        NSAlert* successAlert = [[NSAlert alloc] init];
        [successAlert setMessageText:@"Xuất file thành công!"];
        [successAlert setInformativeText:[NSString stringWithFormat:@"Danh sách gõ tắt đã được xuất ra tại:\n%@", filePath]];
        [successAlert addButtonWithTitle:@"OK"];
        [successAlert setAlertStyle:NSAlertStyleWarning];
        [successAlert beginSheetModalForWindow:self.view.window completionHandler:nil];
    }
}

@end
