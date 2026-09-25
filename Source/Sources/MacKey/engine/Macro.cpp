
#include "Macro.h"
#include "Vietnamese.h"
#include "Engine.h"
#include <iostream>
#include <memory.h>
#include <fstream>

using namespace std;

//main data
map<vector<Uint32>, MacroData> macroMap;

extern int vCodeTable;
static bool _macroFlag = false;
static Uint16 _kChar = 0;

static void convert(const string& str, vector<Uint32>& outData) {
    outData.clear();
    wstring data = utf8ToWideString(str);
    Uint32 t = 0;
    int kSign = -1;
    int k = 0;
    for (int i = 0; i < data.size(); i++) {
        t = (Uint32)data[i];
        
        //find normal character fist
        if (_characterMap.find(t) != _characterMap.end()) {
            outData.push_back(_characterMap[t]);
            continue;
        }
        
        //find character which has tone/mark
        for (map<Uint32, vector<Uint16>>::iterator it = _codeTable[0].begin(); it != _codeTable[0].end(); ++it) {
            kSign = -1;
            k = 0;
            for (int j = 0; j < it->second.size(); j++) {
                if ((Uint16)t == it->second[j]) {
                    kSign = 0;
                    outData.push_back(_codeTable[vCodeTable][it->first][k] | CHAR_CODE_MASK);
                    break;
                }//end if
                k++;
            }
            if (kSign != -1)
                break;
        }
        if (kSign != -1)
            continue;
        
        //find other character
        outData.push_back(t | PURE_CHARACTER_MASK); //mark it as pure character
    }
}

/**
 * data structure:
 * byte 0 and 1: macro count
 *
 * byte n: macroText size (macroTextSize)
 * byte n + macroTextSize: macroText data
 *
 * byte m, m+1: macroContentSize
 * byte m+1 + macroContentSize: macroContent data
 *
 * ...
 * next macro
 */
void initMacroMap(const Byte* pData, const int& size) {
    macroMap.clear();
    if (pData == NULL || size < 0) return;
    Uint16 macroCount = 0;
    Uint32 cursor = 0;
    Uint32 total = (Uint32)size;
    if (total >= 2) {
        memcpy(&macroCount, pData + cursor, 2);
        cursor+=2;
    }
    Uint8 macroTextSize;
    Uint16 macroContentSize;
    for (int i = 0; i < macroCount; i++) {
        // Dữ liệu đã lưu (NSUserDefaults) có thể bị hỏng/cắt cụt (app bị kill
        // giữa lúc ghi, đĩa lỗi...). Phải kiểm tra biên trước mỗi lần đọc,
        // nếu không sẽ đọc tràn ra ngoài buffer và crash lúc khởi động.
        if (cursor + 1 > total) break;
        macroTextSize = pData[cursor++];
        if (cursor + macroTextSize > total) break;
        string macroText((char*)pData + cursor, macroTextSize);
        cursor += macroTextSize;

        if (cursor + 2 > total) break;
        memcpy(&macroContentSize, pData + cursor, 2);
        cursor+=2;
        if (cursor + macroContentSize > total) break;
        string macroContent((char*)pData + cursor, macroContentSize);
        cursor += macroContentSize;

        MacroData data;
        data.macroText = macroText;
        data.macroContent = macroContent;

        vector<Uint32> key;
        convert(macroText, key);
        convert(macroContent, data.macroContentCode);

        macroMap[key] = data;
    }
}

void getMacroSaveData(vector<Byte>& outData) {
    Uint16 totalMacro = (Uint16)macroMap.size();
    outData.push_back((Byte)totalMacro);
    outData.push_back((Byte)(totalMacro>>8));
    
    for (std::map<vector<Uint32>, MacroData>::iterator it = macroMap.begin(); it != macroMap.end(); ++it) {
        outData.push_back((Byte)it->second.macroText.size());
        for (int j = 0; j < it->second.macroText.size(); j++) {
            outData.push_back(it->second.macroText[j]);
        }
        
        Uint16 macroContentSize = (Uint16)it->second.macroContent.size();
        outData.push_back((Byte)macroContentSize);
        outData.push_back(macroContentSize>>8);
        for (int j = 0; j < macroContentSize; j++) {
            outData.push_back(it->second.macroContent[j]);
        }
    }
}

static bool modifyCaseUnicode(Uint32& code, const bool& isUpperCase=true) {
    Uint32 origCode = code;
    if (!(code & CHAR_CODE_MASK)) { //for normal char
        code &= isUpperCase ? CAPS_MASK :  ~CAPS_MASK;
        return code != origCode;
    }
    
    //for unicode character
    for (map<Uint32, vector<Uint16>>::iterator it = _codeTable[vCodeTable].begin(); it != _codeTable[vCodeTable].end(); ++it) {
        for (size_t k = 0; k < it->second.size(); k++) {
            if ((Uint16)code == it->second[k]) {
                if (k % 2 == 0 && !isUpperCase)
                    k++;
                else if (k % 2 != 0 && isUpperCase)
                    k--;
                code = _codeTable[vCodeTable][it->first][k] | CHAR_CODE_MASK;
                return code != origCode;
            }//end if
        }
    }
    return false;
}

static wchar_t convertCharCaseUnicode(wchar_t ch, bool isUpperCase);

static void setCharacterCodeCase(Uint32& code, bool isUpperCase) {
    if (code & PURE_CHARACTER_MASK) {
        wchar_t raw = (wchar_t)(code & ~PURE_CHARACTER_MASK);
        wchar_t converted = convertCharCaseUnicode(raw, isUpperCase);
        code = (Uint32)converted | PURE_CHARACTER_MASK;
        return;
    }
    if (code & CHAR_CODE_MASK) {
        modifyCaseUnicode(code, isUpperCase);
        return;
    }
    Uint16 ch = keyCodeToCharacter(code);
    if (ch != 0) {
        Uint16 newCh = isUpperCase ? (Uint16)toupper(ch) : (Uint16)tolower(ch);
        if (_characterMap.find(newCh) != _characterMap.end()) {
            code = _characterMap[newCh];
            return;
        }
    }
    if (isUpperCase) {
        code |= CAPS_MASK;
    } else {
        code &= ~CAPS_MASK;
    }
}

static wchar_t convertCharCaseUnicode(wchar_t ch, bool isUpperCase) {
    // 1. Basic ASCII
    if (ch >= L'a' && ch <= L'z' && isUpperCase) {
        return ch - 32;
    }
    if (ch >= L'A' && ch <= L'Z' && !isUpperCase) {
        return ch + 32;
    }
    // 2. Look in _codeTable[0] (Unicode table)
    for (map<Uint32, vector<Uint16>>::iterator it = _codeTable[0].begin(); it != _codeTable[0].end(); ++it) {
        for (size_t i = 0; i < it->second.size(); i++) {
            if ((Uint16)ch == it->second[i]) {
                if (i % 2 == 0 && !isUpperCase) {
                    if (i + 1 < it->second.size()) return (wchar_t)it->second[i + 1];
                } else if (i % 2 != 0 && isUpperCase) {
                    if (i > 0) return (wchar_t)it->second[i - 1];
                }
                return ch;
            }
        }
    }
    return ch;
}

static string adjustFirstCharacterCase(const string& str, bool isUpperCase) {
    if (str.empty()) return str;
    wstring wstr = utf8ToWideString(str);
    if (wstr.empty()) return str;
    wstr[0] = convertCharCaseUnicode(wstr[0], isUpperCase);
    return wideStringToUtf8(wstr);
}

bool findMacroWithContext(vector<Uint32>& key, vector<Uint32>& macroContentCode, bool isStartOfSentence) {
    for (size_t idx = 0; idx < key.size(); idx++) {
        key[idx] = getCharacterCode(key[idx]);
    }
    
    bool isKeyHasUpperCase = false;
    for (size_t i = 0; i < key.size(); i++) {
        if (key[i] & CAPS_MASK) {
            isKeyHasUpperCase = true;
            break;
        }
    }
    
    // 1. Direct match in macroMap
    if (macroMap.find(key) != macroMap.end()) {
        macroContentCode.clear();
        MacroData data = macroMap[key];
        macroContentCode = data.macroContentCode;
        if (!isKeyHasUpperCase && !macroContentCode.empty()) {
            setCharacterCodeCase(macroContentCode[0], isStartOfSentence);
        }
        return true;
    }
    
    // 2. Auto caps handling if user typed Shift / Caps
    if (vAutoCapsMacro && isKeyHasUpperCase) {
        _macroFlag = false;
        vector<Uint32> lowerKey = key;
        if (lowerKey.size() > 1 && modifyCaseUnicode(lowerKey[1], false)) {
            _macroFlag = true;
            for (size_t idx = 2; idx < lowerKey.size(); idx++) {
                modifyCaseUnicode(lowerKey[idx], false);
            }
        }
        
        if (lowerKey.size() > 0 && modifyCaseUnicode(lowerKey[0], false)) {
            if (macroMap.find(lowerKey) != macroMap.end()) {
                macroContentCode.clear();
                MacroData data = macroMap[lowerKey];
                macroContentCode = data.macroContentCode;
                for (size_t idx = 0; idx < macroContentCode.size(); idx++) {
                    if (idx == 0 || _macroFlag) {
                        setCharacterCodeCase(macroContentCode[idx], true);
                    }
                }
                return true;
            }
        }
    }
    return false;
}

bool findMacro(vector<Uint32>& key, vector<Uint32>& macroContentCode) {
    return findMacroWithContext(key, macroContentCode, true);
}

bool peekMacroWithContext(const vector<Uint32>& rawKey, string& outMacroText, string& outMacroContent, bool isStartOfSentence) {
    if (rawKey.empty()) return false;
    vector<Uint32> key = rawKey;
    for (size_t i = 0; i < key.size(); i++) {
        key[i] = getCharacterCode(key[i]);
    }
    
    bool isKeyHasUpperCase = false;
    for (size_t i = 0; i < key.size(); i++) {
        if (key[i] & CAPS_MASK) {
            isKeyHasUpperCase = true;
            break;
        }
    }
    
    // Direct match
    map<vector<Uint32>, MacroData>::iterator it = macroMap.find(key);
    if (it != macroMap.end()) {
        outMacroText = it->second.macroText;
        string content = it->second.macroContent;
        if (!isKeyHasUpperCase) {
            content = adjustFirstCharacterCase(content, isStartOfSentence);
        }
        outMacroContent = content;
        return true;
    }
    
    // Auto caps match
    if (vAutoCapsMacro && isKeyHasUpperCase) {
        vector<Uint32> lowerKey = key;
        bool allCaps = false;
        if (lowerKey.size() > 1 && modifyCaseUnicode(lowerKey[1], false)) {
            allCaps = true;
            for (size_t i = 2; i < lowerKey.size(); i++) {
                modifyCaseUnicode(lowerKey[i], false);
            }
        }
        if (lowerKey.size() > 0 && modifyCaseUnicode(lowerKey[0], false)) {
            it = macroMap.find(lowerKey);
            if (it != macroMap.end()) {
                outMacroText = it->second.macroText;
                string content = it->second.macroContent;
                if (allCaps) {
                    wstring wstr = utf8ToWideString(content);
                    for (size_t i = 0; i < wstr.size(); i++) {
                        wstr[i] = convertCharCaseUnicode(wstr[i], true);
                    }
                    content = wideStringToUtf8(wstr);
                } else {
                    content = adjustFirstCharacterCase(content, true);
                }
                outMacroContent = content;
                return true;
            }
        }
    }
    
    return false;
}

bool hasMacro(const string& macroName) {
    vector<Uint32> key;
    convert(macroName, key);
    return (macroMap.find(key) != macroMap.end());
}

bool getMacroContent(const string& macroName, string& outContent) {
    vector<Uint32> key;
    convert(macroName, key);
    map<vector<Uint32>, MacroData>::iterator it = macroMap.find(key);
    if (it != macroMap.end()) {
        outContent = it->second.macroContent;
        return true;
    }
    return false;
}

void getAllMacro(vector<vector<Uint32>>& keys, vector<string>& macroTexts, vector<string>& macroContents) {
    keys.clear();
    macroTexts.clear();
    macroContents.clear();
    for (std::map<vector<Uint32>, MacroData>::iterator it = macroMap.begin(); it != macroMap.end(); ++it) {
        keys.push_back(it->first);
        macroTexts.push_back(it->second.macroText);
        macroContents.push_back(it->second.macroContent);
    }
}

bool addMacro(const string& macroText, const string& macroContent) {
    vector<Uint32> key;
    convert(macroText, key);
    if (macroMap.find(key) == macroMap.end()) { //add new macro
        MacroData data;
        data.macroText = macroText;
        data.macroContent = macroContent;
        convert(macroContent, data.macroContentCode);
        macroMap[key] = data;
    } else { //edit this macro
        macroMap[key].macroContent = macroContent;
        convert(macroContent, macroMap[key].macroContentCode);
    }
    return true;
}

bool deleteMacro(const string& macroText) {
    vector<Uint32> key;
    convert(macroText, key);
    if (macroMap.find(key) != macroMap.end()) {
        macroMap.erase(key);
        return true;
    }
    return false;
}

void clearAllMacros() {
    macroMap.clear();
}

size_t getMacroCount() {
    return macroMap.size();
}

void onTableCodeChange() {
    for (std::map<vector<Uint32>, MacroData>::iterator it = macroMap.begin(); it != macroMap.end(); ++it) {
        convert(it->second.macroContent, it->second.macroContentCode);
    }
}

void saveToFile(const string& path) {
    ofstream myfile;
    myfile.open(path.c_str());
    myfile << ";Compatible MacKey Macro Data file for UniKey*** version=1 ***\n";
    for (std::map<vector<Uint32>, MacroData>::iterator it = macroMap.begin(); it != macroMap.end(); ++it) {
        myfile <<it->second.macroText << ":" << it->second.macroContent<<"\n";
    }
    myfile.close();
}

void readFromFile(const string& path, const bool& append) {
    ifstream myfile(path.c_str());
    string line;
    int k = 0;
    size_t pos = 0;
    string name, content;
    if (myfile.is_open()) {
        if (!append) {
            macroMap.clear();
        }
        while (getline (myfile,line) ) {
            k++;
            if (k == 1) continue;
            pos = line.find(":");
            if (string::npos != pos) {
                name = line.substr(0, pos);
                content = line.substr(pos + 1, line.length() - pos - 1);
				while (name.compare("") == 0 && content.compare("") != 0) {
					pos = content.find(":");
					if (string::npos != pos) {
						name += ":";
						name += content.substr(0, pos);
						content = content.substr(pos + 1, line.length() - pos - 1);
					} else {
						break;
					}
				}

                if (name.compare("") != 0 && !hasMacro(name)) {
                    addMacro(name, content);
                }
            }
        }
        myfile.close();
    }
}
