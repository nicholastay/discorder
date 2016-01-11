# discorder

A recorder for Discord.

I do not take responsibility for any damage caused when you use this software. Licensed under the ISC license.

## Setup
```
$ git clone https://github.com/nicholastay/discorder.git && cd discorder
$ npm install
$ cp config.coffee.template config.coffee
$ vi config.coffee # or your fav editor
$ npm start
```

By default the command is `!rec [channel]` (in the context of a server) to start recording and `!stop` to stop. The saved files will be saved to the root of the application if no save location is defined. All updates will be sent over PM for discrete updates.