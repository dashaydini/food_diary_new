path = 'lib/screens/places_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# נסיר את הסגירה האחרונה המיותרת אם יש יותר מדי סגירות בסוף
while len(lines) > 0 and lines[-1].strip() == '}':
    # נשאיר רק את הסגירות הנכונות למחלקה ול-build
    pass

# נגדיר את הסוף של הקובץ בצורה מדויקת ונקייה בדיוק 2 סגירות מסולסלות בסוף (אחת ל-State ואחת ל-Widget)
# נבדוק מה שורות הסיום וננקה
while len(lines) > 0 and lines[-1].strip() == '':
    lines.pop()

# נוודא ששתי השורות האחרונות הן בדיוק סגירות תקינות
print("Last 5 lines before fix:")
for l in lines[-5:]:
    print(l.rstrip())

# נסדר את הסוף של המחלקה באופן חד משמעי
# נמצא את המקום של ה-PlaceCard ונסגור אחריו נכון
for i in range(len(lines)-1, -1, -1):
    if 'return PlaceCard(' in ''.join(lines[i-10:i]):
        # מכאן ועד הסוף נכתוב את הסגירות המדויקות
        base_lines = lines[:i+15] # נשאיר עד קצת אחרי ה-PlaceCard
        break
else:
    base_lines = lines

# נכתב מחדש את הסוף בצורה נקייה ומדויקת
clean_end = [
    "          );\n",
    "        },\n",
    "      );\n",
    "    }\n",
    "  }\n",
    "}\n"
]

# נחתוך עד לפני שורות הסיום הבעייתיות ונצרף את ה-clean_end
# נחפש את תחילת ה-build של ה-ListView או הטרמינל האחרון
for idx in range(len(lines)-1, 0, -1):
    if 'return PlaceCard(' in lines[idx]:
        # נמצא את סגירת ה-PlaceCard
        end_p = idx
        while end_p < len(lines) and ');' not in lines[end_p]:
            end_p += 1
        
        # מכאן והלאה נחליף הכל ב-clean_end
        lines = lines[:end_p+1] + [
            "        },\n",
            "      );\n",
            "    }\n",
            "  }\n",
            "}\n"
        ]
        break

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("Final brace fixed successfully!")
