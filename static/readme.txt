# crtapi

## enpoints:

GET  /users
GET  /users/[username]
GET  /users/new/[username]

POST /users/[username]?[field]=[value]&[field]=[value]

GET  /key                      reset own apikey
GET  /key/templates            reset own sftp sshkey

GET  /key/[username]           reset other users apikey
GET  /key/templates/[username] reset other users sftp sshkey

GET  /templates                view all available templates
GET  /switch                   view the currently displayed template
POST /switch/[templatename]    switch the displayed template