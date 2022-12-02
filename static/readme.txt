# trintron rest-api

## authentication

all endpoints are secured.
You have to authenticate yourself by providing the API-key 
of your user as a header:

[APIKEY: MyApIkEy]

## enpoints:

GET  /users
GET  /users/[username]
GET  /users/new/[username]

POST /users/[username]?[field]=[value] edit user

GET  /key                      reset own apikey
GET  /key/templates            reset own sftp sshkey

GET  /key/[username]           reset other users apikey
GET  /key/templates/[username] reset other users sftp sshkey


GET  /switch                   view the currently displayed template
POST /switch/[templatename]    switch out the displayed template

GET  /templates                view all available templates
POST, DELETE, GET /templates/[pathtofile]   edit template files