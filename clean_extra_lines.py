path = 'lib/screens/places_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

print("Lines 830 to 845 before cleanup:")
for i in range(max(0, 830 - 1), min(len(lines), 845)):
    print(f"{i+1}: {lines[i].rstrip()}")

# ננקה את השאריות אחרי סגירת ה-PlaceCard (נחפש איפה מופיעים סוגריים מיותרים או נקודה פסיק)
for i in range(830, min(len(lines), 845)):
    line_str = lines[i].strip()
    if line_str in [');', '};', '}', ';', '));']:
        # נבדוק אם זה חלק מיותר אחרי ה-PlaceCard
        # נראה את הקונטקסט מסביב
        pass

# בוא נחתוך ישירות לפי טווח ונקדד מחדש את הסגירה של ה-Builder וה-ListView בצורה נקייה
# נציג את השורות וננקה את מה שמיותר
