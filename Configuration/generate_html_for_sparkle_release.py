
# Takes as input two files:
# 1. File "title" contains the title of the release
# 2. File "latest_changes" contains the latest changes in the release in markdown format

# The output is a file "Release/latest_changes.html" which contains the latest changes in html format

import markdown

def generate_html_for_latest_changes():
    with open('title', 'r') as f:
        title = f.read()
    with open('latest_changes', 'r') as f:
        changes = f.read()
    
    text = '# ' + title + '\n\n' + changes
    html = markdown.markdown(text)

    with open('Release/latest_changes.html', 'w') as f:
        f.write(html)

if __name__ == '__main__':
    generate_html_for_latest_changes()