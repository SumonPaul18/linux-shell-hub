## Using Variable from External File in Shell Script

#### 1st create a file with .txt extension or without any extension
In my case i create a file are name `data` without any extension.
```
nano data
```
```
NAME="Sumon Paul"
EMAIL="sumonpaul267@gmail.com"
```
now, adding as need your variables in that `data` file

#### 2nd create a shell script with .sh extension
```
nano shell.sh
```
```
#!/bin/bash
source data
echo My Name is: $NAME
echo My Email Address: $EMAIL 
```
Here, `shell.sh` file in define that `data` file as mention`source`
