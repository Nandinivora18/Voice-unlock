import os
import re

for root, _, files in os.walk('lib'):
    for f in files:
        if f.endswith('.dart'):
            path = os.path.join(root, f)
            with open(path, 'r', encoding='utf-8') as file:
                content = file.read()
            
            new_content = re.sub(r'\.withOpacity\((.*?)\)', r'.withValues(alpha: \1)', content)
            
            if f == 'home_screen.dart':
                new_content = new_content.replace('bool?  _lastResult;\n', '')
                new_content = new_content.replace('_lastResult    = null;\n', '')
                new_content = new_content.replace('_lastResult    = success;\n', '')

            if new_content != content:
                with open(path, 'w', encoding='utf-8') as file:
                    file.write(new_content)
