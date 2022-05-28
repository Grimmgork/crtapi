# crtapi
Main interface for controlling the crt monitor

## Setup:
place this *system.json* file in the directory of *app.rb*:
```
{
    "wlan":
    {
        "enabled":"true",
        "ssid":"WLAN-NAME",
        "psk":"diesdasananas",
        "country":"DE"
    },
    "templates_authorized_keys_file":"/home/templates/.ssh/authorized_keys",
    "users":
    [
        {
            "name":"eric",
            "api_key":"xxxxxxxxxxxxxxxxx",
            "tier":2
        },
        {
            "name":"milly",
            "api_key":"xxxxxxxxxxxxxxxxx",
            "tier":0
        }
    ]
}
```