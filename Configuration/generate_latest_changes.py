
# look at file Release_Notes.md, take all bullet points under the top header. Also return the value of the first and second headers
# the format in the header: # version - title

def get_latest_release_notes():
    with open('Release_Notes.md', 'r') as f:
        lines = f.readlines()
        first_header = lines[0].strip()
        title = first_header.split(' - ')[1]
        new_version = first_header.split(' - ')[0].replace('# ', '')
        lines = lines[1:]
        latest_changes = ""
        for line in lines:
            if line.strip().startswith('*'):
                latest_changes += line.strip() + "\n"
            elif line.strip().startswith('#'):
                old_version = line.strip().split(' - ')[0].replace('# ', '')
                break
        return title, new_version, latest_changes

if __name__ == '__main__':
    title, new_version, latest_changes = get_latest_release_notes()
    print(title, new_version, latest_changes, sep='\n')
    # write each value to a file
    with open('new_version', 'w') as f:
        f.write(new_version)
    with open('latest_changes', 'w') as f:
        f.write(latest_changes)
    with open('title', 'w') as f:
        f.write(title)