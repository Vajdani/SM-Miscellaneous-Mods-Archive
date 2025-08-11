import os

for i in os.listdir("."):
    if os.path.isdir(i) and ".git" in os.listdir(f"{i}/"):
        print(f"{i}/")