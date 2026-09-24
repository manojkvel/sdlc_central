#!/usr/bin/env python3
"""Generate skills/<name>/SKILL.md from skill.yaml + prompt.md (claude-code adapter format).
Usage: python3 tools/make-skill.py <name> "<allowed-tools>" """
import re, sys, os
name, tools = sys.argv[1], sys.argv[2]
d = os.path.join(os.path.dirname(__file__), '..', 'skills', name)
y = open(os.path.join(d, 'skill.yaml')).read()
g = lambda k: re.search(r'^' + k + r':\s*"?(.*?)"?\s*$', y, re.M).group(1)
body = open(os.path.join(d, 'prompt.md')).read().replace('\nSearch for files: ', '\nGlob: ').replace('\nSearch for content: ', '\nGrep: ')
with open(os.path.join(d, 'SKILL.md'), 'w') as f:
    f.write(f"---\nname: {g('name')}\ndescription: {g('description')}\nargument-hint: \"{g('argument_hint')}\"\nallowed-tools: {tools}\n---\n" + body)
print('wrote', os.path.join('skills', name, 'SKILL.md'))
